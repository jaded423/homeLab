# Frigate RPi5 Build: Pironman Max + Hailo-8L

### **1. Shopping List**

| Item          | Product Link             | Note                       |
| ------------- | ------------------------ | -------------------------- |
| **SBC**       | [Raspberry Pi 5 (8GB)]() | 8GB recommended for NVR.   |
| **Case**      | [Pironman 5-MAX]()       | Dual M.2 slots & cooling.  |
| **AI Module** | [Raspberry Pi AI Kit]()  | Harvest the Hailo-8L chip. |
| **Storage**   | [WD Blue SN580 1TB]()    | M.2 2280 NVMe.             |
| **Power**     | [Official 27W USB-C]()   | Required for PCIe power.   |

---

### **2. Hardware Assembly**

1. **Extract AI Chip:** Unscrew the Hailo-8L module from the green Seeed HAT.
2. **M.2 Installation:**

- Slot 1: Install Hailo-8L module.
- Slot 2: Install WD SN580 NVMe.

3. **Cooling:** Mount the Tower Cooler to the Pi 5 before sliding into the Pironman chassis.

---

### **3. Host OS Configuration**

Run on the Pi 5 before starting Docker.

**Update & Install Drivers:**

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install hailo-all -y
sudo reboot

```

**Optimize PCIe (Edit `/boot/firmware/config.txt`):**

```text
dtparam=pciex1
dtparam=pciex1_gen=3
PCIE_ASPM=off

```

---

### **4. Docker Setup**

`docker-compose.yml`

```yaml
services:
  frigate:
    container_name: frigate
    privileged: true # Required for hardware access
    restart: unless-stopped
    image: ghcr.io/blakeblackshear/frigate:stable
    shm_size: "128mb"
    devices:
      - /dev/hailo0:/dev/hailo0 # Map AI Chip
      - /dev/dri/renderD128:/dev/dri/renderD128 # Map Pi 5 GPU
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./config:/config
      - /path/to/storage:/media/frigate
    ports:
      - "5000:5000"
      - "8554:8554" # RTSP feeds
      - "8555:8555" # WebRTC
    environment:
      FRIGATE_RTSP_PASSWORD: "password"
```

---

### **5. Frigate Configuration**

`config/config.yml`

```yaml
mqtt:
  host: [BROKER_IP]

detectors:
  hailo:
    type: hailo
    device: pcief0

ffmpeg:
  hwaccel_args: preset-rpi-5-64

model:
  width: 640
  height: 640
  input_tensor: nhwc
  input_pixel_format: bgr

cameras:
  example_cam:
    ffmpeg:
      inputs:
        - path: rtsp://[USER]:[PASS]@[IP]:554/stream
          roles:
            - detect
            - record
    detect:
      enabled: True
    objects:
      track:
        - person
        - car

version: 0.14
```

