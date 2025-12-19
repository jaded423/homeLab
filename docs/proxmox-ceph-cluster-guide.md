# Proxmox + Ceph Cluster Setup Guide

## Table of Contents
- [Hardware Layout](#hardware-layout)
- [Initial Setup](#initial-setup)
- [Ceph Configuration](#ceph-configuration)
- [High Availability Setup](#high-availability-setup)
- [Backup Strategies](#backup-strategies)
- [Version Control for /etc](#version-control-for-etc)
- [Disaster Recovery: Node Failure](#disaster-recovery-node-failure)
- [Maintenance & Best Practices](#maintenance--best-practices)

---

## Hardware Layout

### Per-Node Configuration (4 Nodes Total)
```
Node 1-4:
├── 1x 1TB NVMe   → Proxmox OS (boot drive)
├── 1x 4TB NVMe   → Ceph NVMe pool (fast storage)
└── 2x 10TB HDD   → Ceph HDD pool (bulk storage)
```

### Storage Capacity Overview
**NVMe Pool (Fast Tier):**
- Total: 4 OSDs × 4TB = 16TB raw
- Usable (size=3): ~5.3TB
- Use for: VMs, databases, active workloads

**HDD Pool (Bulk Tier):**
- Total: 8 OSDs × 10TB = 80TB raw  
- Usable (size=3): ~26.7TB
- Use for: Backups, archives, media storage

### Network Requirements
- **Minimum:** 10GbE per node
- **Recommended:** Separate public/cluster networks
  - Public: 10GbE for client traffic
  - Cluster: 10GbE+ for Ceph replication/recovery

---

## Initial Setup

### 1. Install Proxmox on All Nodes

```bash
# On each node during installation:
# - Install to 1TB NVMe (e.g., /dev/nvme0n1)
# - Set hostname: pve1, pve2, pve3, pve4
# - Configure static IP addresses
# - Set same root password on all nodes
```

### 2. Post-Installation Configuration

On **first node (pve1)**:
```bash
# Update system
apt update && apt full-upgrade -y

# Remove enterprise repo, add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
rm /etc/apt/sources.list.d/pve-enterprise.list
apt update

# Install useful tools
apt install -y vim git htop iotop
```

### 3. Create Proxmox Cluster

On **pve1**:
```bash
pvecm create my-cluster
```

On **pve2, pve3, pve4**:
```bash
pvecm add <pve1-ip>
```

Verify cluster status:
```bash
pvecm status
pvecm nodes
```

---

## Ceph Configuration

### 1. Install Ceph on All Nodes

On **all nodes**:
```bash
pveceph install --version quincy
```

### 2. Initialize Ceph (First Node Only)

On **pve1**:
```bash
# Initialize Ceph
pveceph init --network 10.0.0.0/24  # Use your cluster network

# Create monitors on all nodes
pveceph mon create
```

On **pve2, pve3, pve4**:
```bash
pveceph mon create
```

### 3. Create Managers

On **all nodes**:
```bash
pveceph mgr create
```

### 4. Create OSDs

On **each node**, identify your drives:
```bash
lsblk
# Example output:
# nvme1n1  →  4TB NVMe for Ceph
# sda      →  10TB HDD for Ceph
# sdb      →  10TB HDD for Ceph
```

Create OSDs (repeat on each node with appropriate device names):
```bash
# NVMe OSD
pveceph osd create /dev/nvme1n1

# HDD OSDs
pveceph osd create /dev/sda
pveceph osd create /dev/sdb
```

Verify OSDs:
```bash
ceph osd tree
# Should show 12 OSDs total:
# - 4 NVMe OSDs (class nvme/ssd)
# - 8 HDD OSDs (class hdd)
```

### 5. Create CRUSH Rules

```bash
# Rule for NVMe pool (only use SSD/NVMe devices)
ceph osd crush rule create-replicated nvme-rule default host nvme

# Rule for HDD pool (only use HDD devices)
ceph osd crush rule create-replicated hdd-rule default host hdd
```

### 6. Create Storage Pools

```bash
# NVMe pool - fast storage
pveceph pool create nvme-pool \
  --add_storages \
  --crush_rule nvme-rule \
  --size 3 \
  --min_size 2 \
  --pg_num 64

# HDD pool - bulk storage
pveceph pool create hdd-pool \
  --add_storages \
  --crush_rule hdd-rule \
  --size 3 \
  --min_size 2 \
  --pg_num 128
```

### 7. Verify Ceph Health

```bash
ceph -s
ceph osd pool ls detail
ceph df
```

You should see `HEALTH_OK` status.

---

## High Availability Setup

### 1. Verify Cluster Quorum

```bash
pvecm status
# Should show 4 nodes, quorum present
```

### 2. Create HA Group (Optional but Recommended)

```bash
# Create HA group via GUI:
# Datacenter → HA → Groups → Create
# Name: main-group
# Nodes: pve1,pve2,pve3,pve4
# Restricted: No
```

Or via CLI:
```bash
ha-manager groupadd main-group -nodes "pve1,pve2,pve3,pve4"
```

### 3. Enable HA for VMs

For any VM stored on Ceph storage:
```bash
# Via CLI (VM ID 100):
ha-manager add vm:100 --group main-group

# Via GUI:
# VM → More → Manage HA
# - State: started
# - Group: main-group
# - Max. Relocate: 1
# - Max. Restart: 3
```

### 4. Test HA Failover

```bash
# Simulate node failure:
# 1. Note which node VM is running on
# 2. Reboot that node
# 3. Watch VM migrate to another node

# Monitor HA status:
ha-manager status
```

---

## Backup Strategies

### 1. Automated Node Configuration Backup

Create backup script on **all nodes**:

```bash
#!/bin/bash
# /root/backup-node-config.sh

BACKUP_DIR="/mnt/nas/proxmox-configs/$(hostname)"
DATE=$(date +%Y%m%d-%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Starting backup for $(hostname) at $DATE"

# Backup critical configuration files
tar czf "$BACKUP_DIR/config-$DATE.tar.gz" \
  --exclude='/etc/pve/.members' \
  --exclude='/etc/pve/priv/lock/*' \
  /etc/pve/ \
  /etc/network/ \
  /etc/hosts \
  /etc/fstab \
  /etc/hostname \
  /etc/ceph/ \
  /root/.ssh/ \
  2>/dev/null

# Backup package list
dpkg --get-selections > "$BACKUP_DIR/packages-$DATE.txt"

# Backup custom scripts
if [ -d /usr/local/bin ]; then
  tar czf "$BACKUP_DIR/scripts-$DATE.tar.gz" /usr/local/bin/ 2>/dev/null
fi

# Backup crontabs
crontab -l > "$BACKUP_DIR/root-crontab-$DATE.txt" 2>/dev/null

# Cleanup old backups (keep 30 days)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
find "$BACKUP_DIR" -name "*.txt" -mtime +30 -delete

echo "Backup complete: $BACKUP_DIR/config-$DATE.tar.gz"
```

Make executable:
```bash
chmod +x /root/backup-node-config.sh
```

Add to crontab (weekly Sunday 2am):
```bash
crontab -e
# Add:
0 2 * * 0 /root/backup-node-config.sh >> /var/log/node-backup.log 2>&1
```

### 2. Manual Cluster Configuration Backup

```bash
# Backup cluster config
pvecm cluster config backup my-cluster-$(date +%Y%m%d)

# Backups stored in: /var/lib/pve-cluster/backup/

# Copy off-cluster regularly:
scp /var/lib/pve-cluster/backup/* user@nas:/backups/proxmox/
```

### 3. VM/Container Backups

Use Proxmox Backup Server (PBS) or built-in backup:

```bash
# Via GUI: Datacenter → Backup → Add
# Schedule: Daily 1:00 AM
# Storage: hdd-pool (Ceph bulk storage)
# Mode: Snapshot (for running VMs)
# Compression: ZSTD

# Via CLI:
vzdump <VMID> --storage hdd-pool --mode snapshot --compress zstd
```

### 4. Backup Storage Recommendations

**What to backup:**
- ✅ Node configs (`/etc/pve`, `/etc/network`, etc.)
- ✅ Custom scripts and automations
- ✅ VM/container backups (via PBS or vzdump)
- ✅ Package lists
- ✅ Ceph configuration

**What NOT to backup:**
- ❌ Full disk images of OS drives (waste of space)
- ❌ Ceph data (already replicated 3x)
- ❌ `/var/lib/pve-cluster/` (cluster syncs this)

---

## Version Control for /etc

### 1. Initialize Git Repository

On **each node**:

```bash
cd /etc

# Initialize repo
git init

# Create .gitignore
cat > .gitignore << 'EOF'
# Ignore sensitive files
shadow
shadow-
gshadow
gshadow-
passwd-
group-
*.key
*.pem
pve/priv/*
ssl/private/*

# Ignore binary/cache files
*.pyc
*.cache
udev/hwdb.bin

# Ignore large/dynamic files
pve/.members
pve/priv/lock/*
EOF

# Add initial files
git add \
  pve/ \
  network/ \
  hosts \
  hostname \
  fstab \
  resolv.conf \
  ceph/ \
  apt/sources.list.d/ \
  .gitignore

# Initial commit
git config user.name "Proxmox Admin"
git config user.email "admin@yourdomain.com"
git commit -m "Initial Proxmox configuration for $(hostname)"
```

### 2. Create Remote Repository

On your Git server or GitHub:
```bash
# Create repo: proxmox-configs
# Clone it locally with separate folders per node:
git clone git@github.com:youruser/proxmox-configs.git
cd proxmox-configs
mkdir pve1 pve2 pve3 pve4
```

### 3. Setup Automated Commits & Push

Create script on **each node**:

```bash
#!/bin/bash
# /root/git-commit-config.sh

cd /etc

# Check for changes
if [[ -n $(git status -s) ]]; then
  # Add all tracked files
  git add -A
  
  # Commit with timestamp
  git commit -m "Auto-commit config changes - $(date '+%Y-%m-%d %H:%M:%S')"
  
  # Push to remote (if configured)
  if git remote | grep -q origin; then
    git push origin main
  fi
  
  echo "Config changes committed and pushed"
else
  echo "No config changes detected"
fi
```

Make executable and add to crontab:
```bash
chmod +x /root/git-commit-config.sh

crontab -e
# Add (daily at 11pm):
0 23 * * * /root/git-commit-config.sh >> /var/log/git-config.log 2>&1
```

### 4. Manual Commits for Major Changes

```bash
cd /etc
git add pve/qemu-server/100.conf
git commit -m "Added new VM 100 configuration"
git push origin main
```

### 5. Review Config History

```bash
cd /etc
git log --oneline
git diff HEAD~1  # See what changed in last commit
git show <commit-hash>  # View specific change
```

---

## Disaster Recovery: Node Failure

### Scenario: Node 3 Dies Completely

**What happens automatically:**
- ✅ VMs on node 3 (stored in Ceph) auto-restart on nodes 1, 2, or 4 via HA
- ✅ Ceph rebalances data across remaining 3 nodes
- ✅ Cluster quorum maintained (3/4 nodes online)
- ✅ All services continue running normally

### Step-by-Step Recovery Process

#### Phase 1: Immediate Response (While Node 3 is Down)

```bash
# On any surviving node (e.g., pve1):

# 1. Check cluster status
pvecm status
# Quorum should still be OK with 3/4 nodes

# 2. Check Ceph health
ceph -s
# Status: HEALTH_WARN (expected - degraded with node down)
ceph osd tree
# Node 3 OSDs will show "down"

# 3. Verify VMs migrated
ha-manager status
# VMs should be running on other nodes

# 4. Monitor Ceph recovery (optional)
ceph -w
# Watch rebalancing progress
```

**DO NOT** remove node 3 from cluster yet - give yourself time to rebuild.

#### Phase 2: Install Replacement Hardware

**Requirements for replacement:**
- Same drive configuration (1TB NVMe, 4TB NVMe, 2x10TB HDD)
- Same network connectivity
- Can use same hostname (pve3) or new name

**Steps:**

1. **Physical setup:**
   - Install drives in replacement server
   - Connect to same network
   - Verify network connectivity to other nodes

2. **Install fresh Proxmox:**
   ```bash
   # During installation:
   # - Hostname: pve3 (or pve3-new if using new hardware)
   # - IP: Same IP as failed node, OR use new IP temporarily
   # - Root password: Same as other nodes
   ```

3. **Post-install configuration:**
   ```bash
   # On new pve3:
   apt update && apt full-upgrade -y
   
   # Configure repos
   echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
   rm /etc/apt/sources.list.d/pve-enterprise.list
   apt update
   
   # Install tools
   apt install -y vim git htop iotop
   ```

#### Phase 3: Remove Old Node from Cluster

**On surviving node (e.g., pve1):**

```bash
# 1. Check cluster members
pvecm nodes

# 2. Remove failed node
pvecm delnode pve3

# 3. Verify removal
pvecm status
pvecm nodes
```

**Important:** If old node might come back online, physically disconnect it first to prevent split-brain!

#### Phase 4: Join New Node to Cluster

**On new pve3:**

```bash
# Join cluster
pvecm add <IP-of-pve1>
# Enter root password of pve1 when prompted

# Verify join
pvecm status
pvecm nodes
```

**On pve1 (or any node):**
```bash
# Verify new node is in cluster
pvecm status
# Should show 4 nodes, all online
```

#### Phase 5: Reinstall and Configure Ceph

**On new pve3:**

```bash
# 1. Install Ceph
pveceph install --version quincy

# 2. Create monitor
pveceph mon create

# 3. Create manager
pveceph mgr create

# 4. Identify drives
lsblk
# nvme1n1 = 4TB NVMe for Ceph
# sda     = 10TB HDD for Ceph  
# sdb     = 10TB HDD for Ceph

# 5. Create OSDs
pveceph osd create /dev/nvme1n1  # NVMe
pveceph osd create /dev/sda      # HDD 1
pveceph osd create /dev/sdb      # HDD 2

# 6. Verify OSDs are up
ceph osd tree
# All 12 OSDs should be "up" and "in"
```

#### Phase 6: Wait for Ceph Rebalancing

```bash
# Monitor rebalancing progress
ceph -s
ceph -w  # Live watch mode

# Check progress
ceph osd pool ls detail
ceph df

# Typical rebalancing time:
# - Light load: 30 minutes - 2 hours
# - Heavy load: 4-12 hours
# - Depends on: data amount, network speed, cluster load
```

**Health progression:**
1. `HEALTH_WARN` → Degraded, recovery in progress
2. `HEALTH_OK` → All data replicated properly

#### Phase 7: Restore Node Configuration

**Option A: Restore from backup**
```bash
# On new pve3:
cd /root
scp user@nas:/backups/proxmox/pve3/config-YYYYMMDD.tar.gz .
tar xzf config-YYYYMMDD.tar.gz -C /

# Restore crontab
crontab /root/crontab-backup.txt

# Restore custom scripts
# (if needed, based on your backup)
```

**Option B: Pull from Git**
```bash
# On new pve3:
cd /etc
git init
git remote add origin git@github.com:youruser/proxmox-configs.git
git fetch origin
git checkout -b main origin/main

# Or manually copy specific configs you need
```

#### Phase 8: Verify Everything

```bash
# 1. Cluster health
pvecm status
# Should show 4/4 nodes

# 2. Ceph health
ceph -s
# Should be HEALTH_OK

# 3. HA status
ha-manager status
# All VMs should be in expected state

# 4. Test VM migration
# Move a test VM to pve3 to verify it's working:
qm migrate 100 pve3

# 5. Run backup script to re-establish baseline
/root/backup-node-config.sh
```

### Recovery Timeline Expectations

| Phase | Time | Can Skip? |
|-------|------|-----------|
| VMs auto-migrate | 1-5 minutes | Automatic |
| Install new Proxmox | 10-20 minutes | No |
| Remove old/add new node | 5 minutes | No |
| Install Ceph + create OSDs | 10-15 minutes | No |
| Ceph rebalance | 30 min - 12 hours | No (automatic) |
| Restore configs | 5-10 minutes | Yes (if acceptable) |

**Total downtime for affected VMs:** 1-5 minutes (just the HA migration)

**Total time to full cluster health:** 1-12 hours (depending on Ceph rebalance)

---

## Maintenance & Best Practices

### Daily Checks

```bash
# Quick cluster health check script
#!/bin/bash
# /root/cluster-health-check.sh

echo "=== Proxmox Cluster Status ==="
pvecm status | grep -A5 "Quorum"

echo -e "\n=== Ceph Health ==="
ceph -s

echo -e "\n=== High Availability ==="
ha-manager status

echo -e "\n=== OSD Status ==="
ceph osd tree | grep -E "up|down"

echo -e "\n=== Storage Usage ==="
ceph df
```

### Weekly Tasks

- ✅ Review backup logs
- ✅ Check Ceph performance: `ceph osd perf`
- ✅ Review HA migration history
- ✅ Update packages: `apt update && apt list --upgradable`

### Monthly Tasks

- ✅ Full cluster update (one node at a time)
- ✅ Review and clean old VM backups
- ✅ Test HA failover on non-critical VM
- ✅ Verify off-site config backups

### Updating Proxmox (Rolling Update)

**NEVER update all nodes at once!**

```bash
# Node by node:

# 1. On pve1:
apt update && apt full-upgrade
# If kernel update, reboot:
reboot

# Wait for pve1 to rejoin cluster and Ceph to stabilize

# 2. Repeat for pve2, pve3, pve4
# Always wait for cluster/Ceph to stabilize between nodes
```

### Performance Tuning

**Ceph performance:**
```bash
# Enable fast read on pools (if all OSDs are SSD/NVMe)
ceph osd pool set nvme-pool fast_read 1

# Adjust PG autoscaler
ceph osd pool set nvme-pool pg_autoscale_mode on
ceph osd pool set hdd-pool pg_autoscale_mode on
```

**Network tuning** (`/etc/sysctl.conf`):
```bash
# Increase network buffers for Ceph
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 87380 67108864
```

Apply: `sysctl -p`

### Monitoring Recommendations

- **Built-in:** Proxmox web GUI metrics
- **Lightweight:** Netdata (real-time monitoring)
- **Advanced:** Prometheus + Grafana
- **Ceph-specific:** Ceph Dashboard (built-in)

Enable Ceph dashboard:
```bash
ceph mgr module enable dashboard
ceph dashboard create-self-signed-cert
ceph dashboard ac-user-create admin password administrator
# Access: https://<node-ip>:8443
```

### Common Issues & Solutions

**Issue:** Ceph shows HEALTH_WARN "clock skew"
```bash
# Solution: Sync time on all nodes
apt install -y chrony
systemctl enable --now chrony
```

**Issue:** OSD full/near-full warnings
```bash
# Check usage:
ceph df
ceph osd df tree

# Rebalance or add more OSDs
```

**Issue:** VM won't migrate (HA failing)
```bash
# Check reasons:
ha-manager status
journalctl -u pve-ha-lrm -f

# Common causes:
# - Local storage in VM config
# - Network issues
# - Resource constraints on target node
```

**Issue:** Node won't rejoin cluster after reboot
```bash
# Check:
systemctl status pve-cluster
systemctl status corosync

# Restart cluster services:
systemctl restart pve-cluster
systemctl restart corosync
```

---

## Quick Reference Commands

### Cluster Management
```bash
pvecm status              # Cluster status
pvecm nodes               # List nodes
pvecm add <node-ip>       # Add node
pvecm delnode <name>      # Remove node
```

### Ceph Management
```bash
ceph -s                   # Cluster health
ceph -w                   # Watch live
ceph osd tree             # OSD layout
ceph df                   # Storage usage
ceph osd pool ls detail   # Pool info
```

### High Availability
```bash
ha-manager status         # HA status
ha-manager add vm:100     # Enable HA for VM
ha-manager remove vm:100  # Disable HA
ha-manager migrate vm:100 pve2  # Manual migrate
```

### VM Management
```bash
qm list                   # List VMs
qm start 100              # Start VM
qm stop 100               # Stop VM
qm migrate 100 pve2       # Migrate VM
```

---

## Conclusion

This setup provides:
- ✅ **High availability** for all VMs stored on Ceph
- ✅ **Automatic failover** when nodes go down
- ✅ **Redundant storage** with 3x replication
- ✅ **Tiered storage** (fast NVMe + bulk HDD)
- ✅ **Simple recovery** from node failures
- ✅ **Scalable design** (easy to add more nodes)

**Key Principle:** Your VMs are safe in Ceph. Nodes are cattle, not pets - they can be rebuilt quickly.

Keep your configs backed up, test your HA occasionally, and you'll sleep well knowing your infrastructure can survive a node failure! 🚀
