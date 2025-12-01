# Twingate Pi-hole Setup Guide

**Goal**: Enable secure remote access to Pi-hole DNS and admin interface via Twingate Zero Trust network.

**Last Updated**: November 13, 2025

---

## Overview

This guide sets up Pi-hole as a Twingate resource, allowing:
- Remote DNS queries to Pi-hole (ad-blocking while away from home)
- Access to Pi-hole web admin interface remotely
- Secure DNS-over-TLS via Twingate tunnel
- No port forwarding or dynamic DNS required

---

## Prerequisites

✅ **Already Configured:**
- Twingate Connector running on CachyOS server (192.168.1.228)
- Pi-hole running on Raspberry Pi (192.168.1.191)
- DNS-over-TLS configured with dnsdist (port 8853)
- SSL certificates installed and valid

✅ **You Need:**
- Twingate Admin Console access: https://jaded423.twingate.com
- Twingate app installed on phone/remote devices

---

## Step 1: Add Pi-hole as Twingate Resource

### Log into Twingate Admin Console

**URL**: https://jaded423.twingate.com

### Create Resources

We'll create **three resources** for different Pi-hole services:

#### Resource 1: Pi-hole DNS (Port 53)

**Purpose**: Regular DNS queries for ad-blocking

1. Go to **Resources** → **Add Resource**
2. Fill in details:
   - **Name**: `Pi-hole DNS`
   - **Address**: `192.168.1.191`
   - **Protocols**:
     - ✅ TCP, Port: `53`
     - ✅ UDP, Port: `53`
   - **Connector**: Select your existing connector (running on CachyOS server)
3. Click **Add Resource**

#### Resource 2: Pi-hole DNS-over-TLS (Port 8853)

**Purpose**: Encrypted DNS queries

1. Go to **Resources** → **Add Resource**
2. Fill in details:
   - **Name**: `Pi-hole DNS-over-TLS`
   - **Address**: `192.168.1.191`
   - **Protocols**:
     - ✅ TCP, Port: `8853`
   - **Connector**: Select your existing connector
3. Click **Add Resource**

#### Resource 3: Pi-hole Web Admin (Port 80/443)

**Purpose**: Access Pi-hole admin dashboard remotely

1. Go to **Resources** → **Add Resource**
2. Fill in details:
   - **Name**: `Pi-hole Admin`
   - **Address**: `192.168.1.191`
   - **Protocols**:
     - ✅ TCP, Port: `80` (HTTP)
     - ✅ TCP, Port: `443` (HTTPS)
   - **Connector**: Select your existing connector
3. Click **Add Resource**

---

## Step 2: Assign Resources to Users

### Assign to Your Account

For each resource created above:

1. Click on the resource name
2. Go to **Access** tab
3. Click **Add User/Group**
4. Select your user account
5. Click **Save**

### Assign to Family Members (Optional)

If family members need ad-blocking on their phones:

1. Add them as users in Twingate (if not already)
2. Assign them **Pi-hole DNS** resource only (not admin access)
3. They can install Twingate app and configure DNS

---

## Step 3: Test Access from Your Mac

### Connect to Twingate

```bash
# Check if Twingate is installed
which twingate

# If not installed, download from:
# https://www.twingate.com/download

# Connect to your network
# (Usually via menu bar app or:)
twingate connect
```

### Test DNS Access

```bash
# Test regular DNS through Twingate
dig @192.168.1.191 google.com

# Test DNS-over-TLS through Twingate
dig @192.168.1.191 -p 8853 +tls google.com

# Test web admin access
curl -I http://192.168.1.191/admin
```

### Access Pi-hole Admin in Browser

With Twingate connected:
```
http://192.168.1.191/admin
```

Should load the Pi-hole dashboard!

---

## Step 4: Configure Phone for Remote Pi-hole DNS

### Install Twingate App

**iOS**: App Store → Search "Twingate"
**Android**: Play Store → Search "Twingate"

### Connect to Network

1. Open Twingate app
2. Sign in with your account
3. Connect to **jaded423** network
4. Verify connection shows green/connected

### Configure DNS (Android)

**Option A: System-Wide Private DNS (Recommended)**

1. Settings → Network & Internet → Private DNS
2. Select "Private DNS provider hostname"
3. Enter: `192.168.1.191` (while Twingate connected)
4. Save

**Option B: Twingate DNS Override**

Some Twingate clients allow DNS override:
1. Twingate app → Settings
2. DNS Settings (if available)
3. Set custom DNS: `192.168.1.191`

### Configure DNS (iOS)

**iOS 14+**

1. Settings → General → VPN & Device Management
2. DNS Configuration → Add Configuration
3. Select "Manual"
4. Add DNS Server: `192.168.1.191`
5. Save

**Alternative: Use DNS Profile**

Create a configuration profile with Pi-hole DNS while Twingate is connected.

---

## Step 5: Test Remote Access

### Test from Phone (Away from Home)

1. **Disconnect from home WiFi** (use cellular data)
2. **Connect Twingate app**
3. **Visit a site with ads**: Should see ads blocked
4. **Check Pi-hole admin** (if assigned): http://192.168.1.191/admin
5. **Verify in Pi-hole**: Should see queries from your phone

### Test DNS Resolution

**From phone browser (while Twingate connected):**
```
http://192.168.1.191/admin
```

Look for your phone's queries in the Pi-hole dashboard!

---

## Troubleshooting

### Can't Access Pi-hole Through Twingate

**Check Connector Status:**

```bash
# On CachyOS server
ssh jaded@192.168.1.228
docker ps | grep twingate

# Should show connector running
```

**Check Resource Configuration:**
- Ensure Pi-hole IP is correct (192.168.1.191)
- Verify ports are correct (53, 8853, 80, 443)
- Confirm resource is assigned to your user

**Check Network Connectivity:**
```bash
# From Mac with Twingate connected
ping 192.168.1.191
telnet 192.168.1.191 53
```

### DNS Queries Not Going Through Pi-hole

**Verify DNS Configuration:**

**Android:**
```
Settings → Network & Internet → Private DNS
Should show: 192.168.1.191
```

**iOS:**
```
Settings → General → VPN & Device Management → DNS
Should show: 192.168.1.191
```

**Check Pi-hole is Receiving Queries:**
```bash
# SSH to Pi-hole
ssh pi@192.168.1.191

# Watch live queries
pihole -t
```

### Twingate Connection Issues

**Restart Connector:**
```bash
# On CachyOS server
ssh jaded@192.168.1.228
cd ~/setup
docker-compose restart
```

**Check Connector Logs:**
```bash
docker logs twingate-connector -f
```

**Verify in Admin Console:**
- https://jaded423.twingate.com
- Connectors → Should show green/online

---

## Advanced Configuration

### DNS-over-TLS via Twingate

Since you have DoT configured on port 8853, you can use encrypted DNS:

**Android 9+ (Private DNS with TLS):**

While this requires a domain name by default, you can:
1. Connect to Twingate
2. Use dnsdist on port 8853 directly
3. Configure apps that support DoT to use: `192.168.1.191:8853`

**iOS (DNS Profile):**

Create a DNS profile that uses DoT endpoint via Twingate IP.

### Split DNS Configuration

**Use Pi-hole Only for Specific Queries:**

Some Twingate setups allow split DNS:
- Home network queries → Pi-hole (via Twingate)
- Other queries → Default DNS

Check Twingate app settings for split DNS options.

---

## Performance Considerations

### Latency

**Expected Latency:**
- Local DNS query: 1-5ms
- Via Twingate (remote): 20-50ms (depends on internet speed)
- Still fast enough for normal browsing

**Optimization:**
- Keep Twingate connector on fast, always-on server (✅ CachyOS server)
- Use Pi-hole for queries only, not as VPN for all traffic
- Phone caches DNS results, reduces queries

### Battery Impact (Phone)

**Twingate App:**
- Minimal battery drain when connected but idle
- Only routes traffic to specific resources (not full VPN)
- Much more efficient than traditional VPN

**DNS Queries:**
- Pi-hole DNS uses negligible bandwidth
- No noticeable battery impact

---

## Security Notes

### Current Security Posture

✅ **Secure:**
- Twingate uses Zero Trust model
- Encrypted tunnel for all traffic
- No ports exposed to internet
- Certificate-based authentication

✅ **Pi-hole Protected:**
- Only accessible via Twingate (no public exposure)
- No port forwarding required
- Can't be discovered by scanning your home IP

### Best Practices

**Twingate:**
- Enable 2FA on Twingate account
- Review access logs monthly
- Remove unused resources/users

**Pi-hole:**
- Keep Pi-hole updated: `pihole -up`
- Monitor for unusual query patterns
- Review blocklists regularly

---

## Alternative: Tailscale (If You Prefer)

I noticed your Mac was using Tailscale DNS (100.95.0.251). If you already have Tailscale set up:

### Use Tailscale Instead

**Advantages:**
- Simpler setup (no resource configuration)
- Use Tailscale IP directly for Pi-hole
- Built-in MagicDNS support
- Less management overhead

**Setup:**
1. Add Pi-hole to Tailscale network
2. Configure DNS in Tailscale settings
3. Point to Pi-hole's Tailscale IP

**Choose One:**
- Use **Twingate** for granular access control
- Use **Tailscale** for simpler setup
- Don't mix both for same device (choose one)

---

## Maintenance Checklist

### Weekly
- [ ] Check Twingate connector status (should be online)
- [ ] Verify Pi-hole is blocking ads remotely
- [ ] Test access from phone while away from home

### Monthly
- [ ] Review Twingate access logs
- [ ] Check Pi-hole query logs for unusual patterns
- [ ] Update Pi-hole blocklists: `pihole -g`
- [ ] Verify SSL certificate expiry (should auto-renew)

### Quarterly
- [ ] Update Pi-hole: `pihole -up`
- [ ] Review and prune Twingate users/resources
- [ ] Test failover (what happens if Twingate is down?)
- [ ] Backup Pi-hole configuration

---

## Quick Reference Commands

```bash
# Connect to Twingate (Mac)
twingate connect

# Test DNS through Twingate
dig @192.168.1.191 google.com

# Access Pi-hole admin (with Twingate connected)
open http://192.168.1.191/admin

# Check Twingate connector status
ssh jaded@192.168.1.228 "docker ps | grep twingate"

# View Pi-hole live queries
ssh pi@192.168.1.191 "pihole -t"

# Restart Twingate connector if needed
ssh jaded@192.168.1.228 "cd ~/setup && docker-compose restart"
```

---

## Success Criteria

You'll know it's working when:

✅ **From anywhere with cellular data:**
1. Connect Twingate app on phone
2. Browse to a site with ads
3. Ads are blocked (Pi-hole working)
4. Can access Pi-hole admin: http://192.168.1.191/admin
5. See your phone's queries in Pi-hole dashboard

✅ **No port forwarding required**
✅ **No dynamic DNS headaches**
✅ **Secure, encrypted access**

---

## Next Steps

1. **Now**: Log into Twingate admin console and add resources
2. **Test**: Verify access from Mac first
3. **Mobile**: Configure phone and test while away from home
4. **Document**: Update this file with any phone-specific DNS configuration
5. **When Pi 5 arrives**: Migrate setup to new Pi (update Twingate resources)

---

## Related Documentation

- [Pi-hole Setup](pihole-setup.md)
- [Twingate on CachyOS Server](~/.claude/docs/homelab.md#3-twingate-connector)
- [Home Lab Overview](../CLAUDE.md)

---

## Proxmox Headless Access (Service Account)

**Added**: December 1, 2025

For server-to-server communication (like Proxmox accessing Mac), use a Twingate Service Account to avoid browser re-authentication.

### Setup Service Account

1. **Create Service Account** in Twingate Admin:
   - Go to **Team** → **Service Accounts**
   - Click **Create Service Account**
   - Name:  (or similar)
   - Generate a **Service Key** (downloads as JSON)

2. **Assign Resources**:
   - Assign the resources the service account needs (e.g., )

3. **Install on Proxmox**:
   ```bash
   # Save the service key
   cat > /etc/twingate/service_key.json << 'KEYEOF'
   {
     "version": "1",
     "network": "jaded423.twingate.com",
     "service_account_id": "<your-id>",
     "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
     "key_id": "<your-key-id>",
     "expires_at": "2026-12-01T16:41:29+00:00",
     "login_path": "/api/v4/headless/login"
   }
   KEYEOF

   # Secure the file
   chmod 600 /etc/twingate/service_key.json

   # Configure Twingate for headless mode
   twingate setup --headless /etc/twingate/service_key.json

   # Start Twingate
   twingate start
   ```

4. **Verify**:
   ```bash
   twingate status    # Should show: online
   twingate resources # Should list available resources
   ```

### Current Service Accounts

| Service Account | Location | Purpose | Expires |
|-----------------|----------|---------|---------|
| prox-book5-service | Proxmox (192.168.2.250) | SSH to Mac, access home resources | Dec 1, 2026 |

### Benefits

- No browser authentication required
- Survives reboots automatically
- Perfect for server-to-server access
- Audit trail in Twingate admin

### SSH to Mac from Proxmox

```bash
ssh joshuabrown@mac-ssh.local
```

Works from anywhere - Proxmox uses Twingate service account to reach Mac via its connector.

---

## Mac Remote Network Setup

**Added**: December 1, 2025

To SSH into your Mac from anywhere (even when Mac changes networks):

### Architecture

```
Mac (work/home/anywhere)
├── Twingate Client (access OUT)
└── Twingate Connector in Docker (access IN)
    └── Resource: mac-ssh → host.docker.internal:22

Proxmox (home)
└── Twingate Client (service account)
    └── Can reach mac-ssh.local from anywhere
```

### Setup

1. **Create Mac-Remote Network** in Twingate Admin
2. **Deploy Connector on Mac** (Docker):
   ```bash
   docker run -d --restart=unless-stopped \
     --name twingate-mac-ssh \
     -e TWINGATE_NETWORK="jaded423" \
     -e TWINGATE_ACCESS_TOKEN="<token>" \
     -e TWINGATE_REFRESH_TOKEN="<token>" \
     twingate/connector:1
   ```

3. **Create Resource**:
   - Name: 
   - Address:  (routes to Mac host from Docker)
   - Port:  (TCP)
   - Network: Mac-Remote
   - Alias: 

4. **Enable SSH on Mac**:
   - System Settings → General → Sharing → Remote Login → On

5. **Add SSH key** to Mac's 

### Key Detail: host.docker.internal

Since the connector runs in Docker with bridge networking,  points to the container, not the Mac. Use  instead - Docker's special hostname that routes to the host machine.


---

## Proxmox Headless Access (Service Account)

**Added**: December 1, 2025

For server-to-server communication (like Proxmox accessing Mac), use a Twingate Service Account to avoid browser re-authentication.

### Setup Service Account

1. **Create Service Account** in Twingate Admin:
   - Go to **Team** → **Service Accounts**
   - Click **Create Service Account**
   - Name: `prox-book5-service` (or similar)
   - Generate a **Service Key** (downloads as JSON)

2. **Assign Resources**:
   - Assign the resources the service account needs (e.g., `mac-ssh`)

3. **Install on Proxmox**:
   ```bash
   # Save the service key JSON to this file
   nano /etc/twingate/service_key.json

   # Secure the file
   chmod 600 /etc/twingate/service_key.json

   # Configure Twingate for headless mode
   twingate setup --headless /etc/twingate/service_key.json

   # Start Twingate
   twingate start
   ```

4. **Verify**:
   ```bash
   twingate status    # Should show: online
   twingate resources # Should list available resources
   ```

### Current Service Accounts

| Service Account | Location | Purpose | Expires |
|-----------------|----------|---------|---------|
| prox-book5-service | Proxmox (192.168.2.250) | SSH to Mac, access home resources | Dec 1, 2026 |

### Benefits

- No browser authentication required
- Survives reboots automatically
- Perfect for server-to-server access
- Audit trail in Twingate admin

### SSH to Mac from Proxmox

```bash
ssh joshuabrown@mac-ssh.local
```

Works from anywhere - Proxmox uses Twingate service account to reach Mac via its connector.

---

## Mac Remote Network Setup

**Added**: December 1, 2025

To SSH into your Mac from anywhere (even when Mac changes networks):

### Architecture

```
Mac (work/home/anywhere)
├── Twingate Client (access OUT)
└── Twingate Connector in Docker (access IN)
    └── Resource: mac-ssh → host.docker.internal:22

Proxmox (home)
└── Twingate Client (service account)
    └── Can reach mac-ssh.local from anywhere
```

### Setup

1. **Create Mac-Remote Network** in Twingate Admin

2. **Deploy Connector on Mac** (Docker):
   - Go to Networks → Mac-Remote → Deploy Connector
   - Choose Docker and follow the instructions
   - The container should run with `--restart=unless-stopped`

3. **Create Resource**:
   - Name: `mac-ssh`
   - Address: `host.docker.internal` (routes to Mac host from Docker)
   - Port: `22` (TCP)
   - Network: Mac-Remote
   - Alias: `mac-ssh.local`

4. **Enable SSH on Mac**:
   - System Settings → General → Sharing → Remote Login → On

5. **Add SSH key** to Mac's `~/.ssh/authorized_keys`

### Key Detail: host.docker.internal

Since the connector runs in Docker with bridge networking, `127.0.0.1` points to the container, not the Mac. Use `host.docker.internal` instead - Docker's special hostname that routes to the host machine.
