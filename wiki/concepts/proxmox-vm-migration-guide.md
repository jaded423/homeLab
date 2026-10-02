---
type: reference
title: Proxmox VM Migration Guide (laptop → Tower)
tags: [proxmox, migration, vm, tower, book5, how-to]
related: [storage, network-topology, history]
---

# Proxmox VM Migration Guide
## Laptop → Tower

**Last Updated:** November 30, 2025
**Setup:** Samsung laptop (16GB) → Tower (32GB, up to 256GB)
**Target:** VM 102 (Ubuntu Server + Ollama + Docker)

> **Subnet note:** Examples use 192.168.2.x (pre-router-migration). Subnet now 192.168.68.0/22 — swap IPs as needed.

---

## TOC
1. [Options](#options)
2. [Option 1: Backup & Restore](#option-1-backup--restore)
3. [Option 2: Proxmox Cluster](#option-2-proxmox-cluster)
4. [Option 3: CEPH Cluster](#option-3-ceph-cluster)
5. [Pre-Migration](#pre-migration)
6. [Post-Migration](#post-migration)
7. [Testing & Validation](#testing--validation)
8. [Troubleshooting](#troubleshooting)
9. [Future Expansion](#future-expansion)
10. [Quick Reference](#quick-reference)

---

## Options

| Method | Downtime | Complexity | Best For | Keeps Models |
|---|---|---|---|---|
| Backup & Restore | 30-60 min | Low | One-time | ✅ |
| Proxmox Cluster | 0-5 min | Medium | Ongoing flexibility | ✅ |
| Manual Disk Copy | 30-60 min | High | Special cases | ✅ |
| CEPH Cluster | 0 min | High | 3+ nodes | ✅ |

---

## Option 1: Backup & Restore

Best for one-time migration, no need to run both servers concurrently.

### Step 1: Backup on laptop
```bash
ssh root@192.168.2.250
qm stop 102

vzdump 102 \
  --storage local \
  --mode snapshot \
  --compress zstd \
  --notes-template "Migration backup for tower server"

# Output: /var/lib/vz/dump/vzdump-qemu-102-2025_11_30-*.vst.zst (~50-70GB w/ Ollama models)
ls -lh /var/lib/vz/dump/
```

### Step 2: Transfer to tower

Same-network (fastest):
```bash
scp /var/lib/vz/dump/vzdump-qemu-102-*.vst.zst root@<tower-ip>:/var/lib/vz/dump/

# Or resumable
rsync -avP --compress \
  /var/lib/vz/dump/vzdump-qemu-102-*.vst.zst \
  root@<tower-ip>:/var/lib/vz/dump/
```

External drive:
```bash
mkdir -p /mnt/backup
mount /dev/sdb1 /mnt/backup
cp /var/lib/vz/dump/vzdump-qemu-102-*.vst.zst /mnt/backup/
# Unmount, move drive, mount on tower, copy to /var/lib/vz/dump/
```

### Step 3: Restore on tower
```bash
ssh root@<tower-ip>
ls -lh /var/lib/vz/dump/

qmrestore /var/lib/vz/dump/vzdump-qemu-102-*.vst.zst 102
# Or different ID if 102 taken:
qmrestore /var/lib/vz/dump/vzdump-qemu-102-*.vst.zst 202

qm set 102 --memory 16384    # 16GB
qm set 102 --cores 6
qm start 102
qm status 102
```

### Step 4: Update Mac scripts
```bash
ssh root@<tower-ip>
qm guest cmd 102 network-get-interfaces | grep ip-address

# Edit on Mac:
# ~/scripts/bin/ollamaSummary.py — OLLAMA_SERVER = "jaded@<new-tower-vm-ip>"
# ~/scripts/bin/gitBackup.sh — replace 192.168.2.126

ssh jaded@<new-tower-vm-ip> "ollama list"
```

**Pros:** simple, well-tested, all data preserved, can wipe laptop after verify.
**Cons:** 30-60min downtime, manual, no ongoing flexibility.

---

## Option 2: Proxmox Cluster

Best for running both servers long-term, easy migration, HA.

Cluster enables: live migration (zero downtime), shared config, HA (auto-restart on node fail), centralized mgmt, distributed storage (w/ CEPH).

**Requirements:** ≥2 nodes, same network, unique hostnames, DNS or `/etc/hosts`, NTP sync.

### Step 1: Prepare nodes

Laptop:
```bash
ssh root@192.168.2.250
hostnamectl set-hostname proxmox-laptop
ping <tower-ip>
timedatectl status
echo "<tower-ip> proxmox-tower" >> /etc/hosts
```

Tower:
```bash
ssh root@<tower-ip>
hostnamectl set-hostname proxmox-tower
echo "192.168.2.250 proxmox-laptop" >> /etc/hosts
ping 192.168.2.250
```

### Step 2: Create cluster (laptop = master)
```bash
pvecm create homelab-cluster
pvecm status
# Cluster information
# Name:           homelab-cluster
# Quorum:         1 Active
```

### Step 3: Join tower
```bash
# On tower
pvecm add 192.168.2.250
# Enter laptop root password
pvecm status
# Nodes: 2

# Verify from laptop
pvecm nodes
# Node 1 proxmox-laptop
# Node 2 proxmox-tower
```

### Step 4: Migrate VM

Online (zero downtime, 2-5min):
```bash
qm migrate 102 proxmox-tower --online
```

Offline (faster, requires downtime):
```bash
qm stop 102
qm migrate 102 proxmox-tower
qm start 102
```

Web UI: Select VM → Migrate → choose dest → check Online → Migrate.

### Step 5: Shared storage (optional)

NFS:
```bash
# Laptop
apt install nfs-kernel-server
echo "/var/lib/vz *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
exportfs -a

# Tower
apt install nfs-common
mkdir -p /mnt/pve/laptop-storage
mount 192.168.2.250:/var/lib/vz /mnt/pve/laptop-storage

pvesm add nfs laptop-storage \
  --server 192.168.2.250 \
  --export /var/lib/vz \
  --content images,vztmpl,iso
```

CEPH: see Option 3.

### Cluster tips
```bash
pvecm status              # health
pvecm nodes               # list
ha-manager status         # HA status

# Migrate all VMs
qm list
for vmid in 100 101 102; do
  qm migrate $vmid proxmox-tower --online
done

# Prefer tower
ha-manager add vm:102 --group tower-preferred
```

**Pros:** zero downtime, centralized mgmt, easy bidirectional migration, HA foundation, scalable.
**Cons:** more complex, both servers running, needs good net, cluster service overhead.

---

## Option 3: CEPH Cluster

Best for 3+ nodes, distributed storage, max reliability.

CEPH: replicates data across nodes, allows live migration without shared storage, self-heals on drive failure, scales horizontally.

**Min:** 3 nodes, 3 OSDs/node, 10Gbps net, dedicated CEPH net, 4GB RAM/OSD.

### Architecture (future 3-node)
```
Cluster + CEPH
├── Node 1: Laptop (16GB, 2 disks)
├── Node 2: Tower (32GB, 4 disks)
└── Node 3: Future (32GB+, 4 disks)

Replication: 3 (each VM disk on 3 nodes)
Min size: 2 (need 2 copies to write)
Usable: ~66% of raw
```

### Setup

Install on all nodes:
```bash
pveceph install --version quincy
```

Init on first node:
```bash
pveceph init --network 192.168.2.0/24
```

Monitors on all nodes:
```bash
pveceph mon create
```

OSDs:
```bash
pveceph disk list
pveceph osd create /dev/sdb
pveceph osd create /dev/sdc
```

Pool:
```bash
pveceph pool create vm-pool \
  --size 3 \
  --min_size 2 \
  --pg_num 128

pvesm add rbd ceph-vm-storage \
  --pool vm-pool \
  --content images,rootdir
```

Migrate VM to CEPH:
```bash
qm move-disk 102 scsi0 ceph-vm-storage --delete
```

### Adding nodes
```bash
pvecm add 192.168.2.250   # from new node
pveceph install
pveceph mon create
pveceph osd create /dev/sdb
# Auto-rebalances
```

### Network

- 1Gbps: works but slow
- 10Gbps: recommended
- 25Gbps+: optimal for many VMs

Dedicated CEPH net in `/etc/pve/ceph.conf`:
```ini
[global]
    public_network = 192.168.2.0/24     # mgmt
    cluster_network = 10.0.0.0/24       # CEPH repl (10Gbps)
```

Tower RAM: 32GB → ~24GB for VMs, ~8GB CEPH overhead. With 256GB → ~40 OSDs comfortably.

**Pros:** max reliability, no SPOF, infinite scale, instant migrations, self-healing.
**Cons:** 3+ nodes required, complex, 10Gbps ideal, 33% storage efficiency (3x repl), RAM overhead.

---

## Pre-Migration

### Document state
```bash
ssh root@192.168.2.250

qm config 102 > ~/vm-102-config.txt
qm guest cmd 102 network-get-interfaces > ~/vm-102-network.txt
ssh jaded@192.168.2.126 "docker ps -a && systemctl status ollama" > ~/vm-102-services.txt
ssh jaded@192.168.2.126 "ollama list" > ~/vm-102-models.txt
```

### Backup
```bash
vzdump 102 --storage local --compress zstd
cp /etc/pve/qemu-server/102.conf ~/vm-102-backup.conf
qmrestore /var/lib/vz/dump/vzdump-qemu-102-*.vst.zst 999 --test
```

### Update docs
- [ ] `~/.claude/docs/homelab.md` w/ migration date
- [ ] Tower hostname + IP
- [ ] Migration method used
- [ ] Network config

### Verify Mac scripts
```bash
grep -r "192.168.2.126" ~/scripts/
grep -r "192.168.2.250" ~/scripts/
# Update: ~/scripts/bin/ollamaSummary.py (line 28), ~/scripts/bin/gitBackup.sh
```

### Test tower Proxmox
```bash
ssh root@<tower-ip>
pvesm status
free -h
ping <tower-ip>
```

---

## Post-Migration

### 1. Verify boot
```bash
ssh root@<tower-ip>
qm status 102
qm terminal 102
qm guest exec 102 -- journalctl -b
```

### 2. Find new IP
```bash
qm guest cmd 102 network-get-interfaces
qm terminal 102        # then `ip addr show`
# Or check DHCP leases for "ubuntu-serv"
```

### 3. Test services
```bash
ssh jaded@<new-ip>
ollama list
ollama run qwen2.5-coder:7b "test"
docker ps -a
systemctl status ollama
systemctl status smb
systemctl --user status rclone-gdrive
systemctl --user status rclone-elevated
# Samba: Finder Cmd+K smb://<new-ip>/Shared
```

### 4. Update Mac scripts
```bash
cd ~/scripts
nano bin/ollamaSummary.py       # OLLAMA_SERVER = "jaded@<new-ip>"
nano bin/gitBackup.sh           # replace jaded@192.168.2.126
/bin/bash bin/gitBackup.sh      # test
```

### 5. Increase resources
```bash
ssh root@<tower-ip>
qm set 102 --memory 16384
qm set 102 --cores 6
qm shutdown 102 && qm start 102
```

### 6. Test bigger Ollama models
```bash
ssh jaded@<new-ip>
ollama pull phi4:14b
ollama run phi4:14b "Generate a commit message for adding user authentication"
ollama pull qwen2.5:32b
# Update DEFAULT_MODEL in ~/scripts/bin/ollamaSummary.py
```

### 7. Update docs
```bash
nano ~/.claude/docs/homelab.md
# ### YYYY-MM-DD - Migrated VM 102 to Tower
# - Method: backup/cluster/CEPH
# - New IP, RAM 8→16GB, scripts updated, larger models
```

### 8. Static IP

`/etc/netplan/00-installer-config.yaml`:
```yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses:
        - 192.168.2.126/24       # keep same IP
      routes:
        - to: default
          via: 192.168.2.1
      nameservers:
        addresses:
          - 192.168.2.131        # Pi-hole
          - 8.8.8.8
```

```bash
sudo netplan apply
ip addr show
```

Same IP = no script updates needed.

---

## Testing & Validation

### Ollama
```bash
ssh jaded@<vm-ip>
curl http://localhost:11434/api/tags
ollama run qwen2.5-coder:7b "Hello"
ssh jaded@<vm-ip> "ollama run gemma2:2b 'test'"
```

### Docker
```bash
docker ps
# Expected: twingate-connector, jellyfin, qbittorrent, clamav, open-webui
# Jellyfin: http://<vm-ip>:8096
# Open WebUI: http://<vm-ip>:3000
```

### Samba
Finder Cmd+K → `smb://<vm-ip>/Shared` → GoogleDrive, ElevatedDrive, Documents, Music, Pictures, Videos.

### Google Drive
```bash
ssh jaded@<vm-ip>
ls ~/GoogleDrive/
ls ~/elevatedDrive/
systemctl --user status rclone-gdrive
systemctl --user status rclone-elevated
```

### Git backup
```bash
cd ~/scripts
/bin/bash bin/gitBackup.sh
git log -1     # AI-generated commit message
```

### Network
```bash
ping <vm-ip>
scp ~/Downloads/testfile.bin jaded@<vm-ip>:~/    # expect 60+ MB/s on gigabit
```

### Benchmarks

Ollama inference:
```bash
time ssh jaded@<vm-ip> "ollama run qwen2.5-coder:7b 'Generate commit message'"
# 16GB VM: cold ~8-12s, warm ~3-5s
```

Docker:
```bash
docker stats --no-stream
```

CEPH:
```bash
ceph status
ceph osd pool stats
rados bench -p vm-pool 10 write --no-cleanup
# 1Gbps: 100+ MB/s, 10Gbps: 500+ MB/s
```

---

## Troubleshooting

### VM won't boot after restore
```bash
qm config 102 | grep boot
qm set 102 --boot order=scsi0
qm guest exec 102 -- journalctl -b
qm terminal 102
```

### Can't SSH to new IP
```bash
qm guest cmd 102 network-get-interfaces
ssh jaded@<vm-ip> "sudo ufw status"
ssh root@<tower-ip> "qm guest exec 102 -- systemctl status sshd"
```

### Ollama models missing
```bash
ssh jaded@<vm-ip>
ollama list
df -h
ls -lh /usr/share/ollama/.ollama/models/
ollama pull qwen2.5-coder:7b    # if truly missing
```

### Split brain
```bash
ping proxmox-tower
ping proxmox-laptop
pvecm status
# Recreate only as last resort
```

### Quorum lost
```bash
pvecm expected 1     # temporary 1-node operation
```

### CEPH warnings
```bash
ceph status
# clock skew → timedatectl set-ntp true
# too few PGs → increase PG count
# nearfull → add OSDs or delete data
```

---

## Future Expansion

### Phase 1: Laptop + Tower
- [x] Migrate VM 102 to tower
- [ ] 2-node cluster
- [ ] Live migrations
- [ ] Shared NFS (optional)

### Phase 2: 3rd Node (CEPH)
- [ ] 3rd server (PC, NUC, tower)
- [ ] `pvecm add`
- [ ] CEPH on all 3
- [ ] Migrate VMs to CEPH
- [ ] Failover testing

### Phase 3: Multi-Site (see `homelab-multi-site-expansion.md`)
- [ ] Node at second location
- [ ] WireGuard between sites
- [ ] Cluster across sites
- [ ] CEPH replication between sites
- [ ] DR survives site failure

### Phase 4: Production
- [ ] 6+ nodes, 2+ sites
- [ ] CEPH 3-way replication
- [ ] Auto failover
- [ ] Prometheus/Grafana
- [ ] Proxmox Backup Server
- [ ] HAProxy

---

## Related

- `~/.claude/docs/homelab.md` — current setup
- `~/.claude/docs/homelab-expansion.md` — single-site plans
- `~/.claude/docs/homelab-multi-site-expansion.md` — multi-site
- `/var/lib/vz/dump/` — backup location
- [Proxmox Cluster docs](https://pve.proxmox.com/wiki/Cluster_Manager)
- [CEPH docs](https://docs.ceph.com/)

---

## Quick Reference

### Backup & Restore
```bash
vzdump 102 --storage local --compress zstd
qmrestore /path/to/backup.vst.zst 102
qm clone 102 103 --full
```

### Cluster
```bash
pvecm create cluster-name
pvecm add <master-ip>
pvecm status
pvecm nodes
pvecm delnode <nodename>
```

### Migration
```bash
qm migrate 102 target-node --online
qm migrate 102 target-node
qm move-disk 102 scsi0 storage-name
```

### CEPH
```bash
pveceph install
pveceph init --network 192.168.2.0/24
pveceph mon create
pveceph osd create /dev/sdb
ceph status
ceph osd pool create poolname 128
```

### Resources
```bash
qm set 102 --memory 16384
qm set 102 --cores 6
qm resize 102 scsi0 +50G
qm config 102
```
