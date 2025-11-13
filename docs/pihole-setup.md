# Pi-hole Documentation

**Device**: Raspberry Pi 1 Model B+
**Hostname**: pihole (pihole.local)
**Local IP**: 192.168.1.191
**OS**: Raspbian GNU/Linux 13 (Trixie)
**Last Updated**: November 13, 2025

---

## Overview

Network-wide ad blocking DNS server running on Raspberry Pi 1 B+. Provides DNS services for the entire home network with DNS-over-TLS (DoT) support for secure remote access.

**Key Services:**
- Pi-hole DNS ad-blocking (port 53)
- DNS-over-TLS via dnsdist (port 8853)
- Web admin interface (port 80/443)

---

## Pi-hole Configuration

### Version Information

```bash
Core version:  v6.2.2 (Latest)
Web version:   v6.3 (Latest)
FTL version:   v6.3.3 (Latest)
```

### Local Access

**Web Admin Interface:**
```
http://192.168.1.191/admin
https://192.168.1.191/admin
```

**SSH Access:**
```bash
# From CachyOS server
ssh pi@pihole.local

# Direct from Mac (on home network)
ssh pi@192.168.1.191
```

### DNS Service

**Regular DNS:**
- Port: 53 (TCP/UDP)
- Service: pihole-FTL
- Listening: 0.0.0.0:53 (all interfaces)

**Clients Configured:**
- CachyOS server (192.168.1.228) - Primary DNS
- Other devices via DHCP (check router settings)

---

## DNS-over-TLS (DoT) Setup

### Overview

Secure DNS service using dnsdist as a TLS proxy in front of Pi-hole.

**Architecture:**
```
Internet → Port 8853 (DoT) → dnsdist → Pi-hole (port 53) → Upstream DNS
```

### dnsdist Configuration

**Config File**: `/etc/dnsdist/dnsdist.conf`

**Key Settings:**
- DoT Port: **8853** (custom, not standard 853)
- Backend: Pi-hole at 127.0.0.1:53
- Plain DNS: Port 5300 (alternate port)
- Web Interface: 127.0.0.1:8083
- Access Control: Open (0.0.0.0/0)

**Service Status:**
```bash
# Check dnsdist status
systemctl status dnsdist

# View dnsdist logs
journalctl -u dnsdist -f

# Restart dnsdist
sudo systemctl restart dnsdist
```

### SSL Certificate

**Domain**: pihole.jadedviber.com
**Provider**: Let's Encrypt
**Valid**: Nov 10, 2025 - Feb 8, 2026 (3 months)

**Certificate Locations:**
```
/etc/letsencrypt/live/pihole.jadedviber.com/fullchain.pem
/etc/letsencrypt/live/pihole.jadedviber.com/privkey.pem
/etc/letsencrypt/archive/pihole.jadedviber.com/
```

**Auto-Renewal:**
Needs certbot configured for automatic renewal (check crontab).

### Testing DoT

**From Pi-hole itself:**
```bash
dig @127.0.0.1 -p 8853 +tls google.com
```

**From another device (if port forwarded):**
```bash
dig @pihole.jadedviber.com -p 8853 +tls google.com
```

---

## Current Limitations

### DNS Record Issue

**Problem**: Domain doesn't point to home network

```
pihole.jadedviber.com → 35.147.140.96 (unknown cloud IP)
Actual home public IP → 68.203.132.146
```

**Impact**: Remote DoT access via domain name is **not working**

**Solutions:**
1. **Option A**: Update DNS A record to point to current home IP
2. **Option B**: Use Twingate for secure remote access (recommended)
3. **Option C**: Use Tailscale if configured

### Port Forwarding

**Not Currently Configured:**
- Router likely not forwarding port 8853 to 192.168.1.191
- Would be needed if using public domain approach
- Not needed if using Twingate/Tailscale

---

## Remote Access via Twingate (Recommended)

### Why Twingate for Pi-hole?

✅ **Benefits:**
- No port forwarding required
- No dynamic DNS issues
- Zero Trust security model
- Works from anywhere
- Encrypted tunnel

### Setup Steps

1. **Add Pi-hole as Twingate Resource** (admin console)
   - Name: Pi-hole DNS
   - Address: 192.168.1.191:8853 (DoT)
   - Protocol: TCP
   - Also add: 192.168.1.191:53 (regular DNS if needed)
   - Also add: 192.168.1.191:80 (web admin)

2. **Assign to Users**
   - Assign to your user account
   - Assign to family members who need ad-blocking on phones

3. **Configure Device**
   - Connect to Twingate on phone/laptop
   - Set DNS to use Pi-hole via Twingate IP
   - For DoT: Use Twingate IP:8853

### Twingate Admin Console

**URL**: https://jaded423.twingate.com
**Connector**: Running on CachyOS server (192.168.1.228)

---

## Network Configuration

### Listening Ports

```
Port 53    (TCP/UDP) - Pi-hole FTL (regular DNS)
Port 80    (TCP)     - Pi-hole FTL (web admin HTTP)
Port 443   (TCP)     - Pi-hole FTL (web admin HTTPS)
Port 5300  (TCP/UDP) - dnsdist (alternate DNS port)
Port 8853  (TCP)     - dnsdist (DNS-over-TLS)
Port 8083  (TCP)     - dnsdist (web interface, localhost only)
```

### Network Interface

**Interface**: eth0 (Ethernet)
**IP**: 192.168.1.191/24
**Gateway**: 192.168.1.1
**DHCP**: Dynamic (consider setting static)

---

## Maintenance

### Regular Tasks

**Weekly:**
- Check Pi-hole admin panel for stats
- Review blocked queries
- Check for Pi-hole updates: `pihole -up`

**Monthly:**
- Update Pi lists: `pihole -g`
- Check SSL certificate expiry
- Review dnsdist logs for errors

**Every 3 Months:**
- Renew Let's Encrypt certificate (should be automatic)
- Review and update blocklists
- Check system updates: `sudo apt update && sudo apt upgrade`

### Certificate Renewal

**Check Certificate Expiry:**
```bash
sudo openssl x509 -in /etc/letsencrypt/live/pihole.jadedviber.com/cert.pem -noout -dates
```

**Manual Renewal (if needed):**
```bash
sudo certbot renew
sudo systemctl restart dnsdist
```

### Service Management

**Pi-hole:**
```bash
pihole status                   # Check status
pihole restartdns              # Restart DNS service
pihole -up                     # Update Pi-hole
pihole -g                      # Update gravity (blocklists)
pihole -c                      # Chronometer (live stats)
```

**dnsdist:**
```bash
systemctl status dnsdist       # Check status
sudo systemctl restart dnsdist # Restart service
journalctl -u dnsdist -f       # View logs
```

---

## Troubleshooting

### DNS Not Working

**Check Pi-hole is running:**
```bash
pihole status
systemctl status pihole-FTL
```

**Check network connectivity:**
```bash
ping 8.8.8.8
ping google.com
```

**Check if Pi-hole can resolve:**
```bash
dig @127.0.0.1 google.com
```

### DoT Not Working

**Check dnsdist is running:**
```bash
systemctl status dnsdist
sudo ss -tlnp | grep 8853
```

**Test locally first:**
```bash
dig @127.0.0.1 -p 8853 +tls google.com
```

**Check certificate is valid:**
```bash
sudo openssl x509 -in /etc/letsencrypt/live/pihole.jadedviber.com/cert.pem -noout -dates
```

**Check dnsdist logs:**
```bash
journalctl -u dnsdist -n 50
```

### Web Interface Not Accessible

**Check FTL is serving HTTP:**
```bash
curl -I http://localhost/admin
sudo ss -tlnp | grep :80
```

**Restart Pi-hole:**
```bash
pihole restartdns
```

### Certificate Expired

```bash
# Renew certificate
sudo certbot renew --force-renewal

# Restart dnsdist to use new cert
sudo systemctl restart dnsdist

# Verify new certificate
sudo openssl x509 -in /etc/letsencrypt/live/pihole.jadedviber.com/cert.pem -noout -dates
```

---

## Phone Configuration

### Using Twingate (Recommended)

1. Install Twingate app on phone
2. Connect to jaded423 network
3. Configure Private DNS:

**Android:**
- Settings → Network & Internet → Private DNS
- Select "Private DNS provider hostname"
- Enter: `pihole.jadedviber.com` (when Twingate connected)
- Port: 8853

**iOS:**
- Settings → General → VPN & Device Management → DNS
- Add DNS Configuration
- Configure DoT with Twingate IP of Pi-hole

### Using Domain (If DNS Record Fixed)

**Android:**
- Settings → Network & Internet → Private DNS
- Enter: `pihole.jadedviber.com`

**iOS:**
- Requires DNS profile or app like DNSCloak
- Configure DoT server: pihole.jadedviber.com:8853

---

## Hardware Specifications

**Device**: Raspberry Pi 1 Model B+
**RAM**: 512MB
**CPU**: Single-core 700MHz ARM
**Network**: 10/100 Ethernet
**Power**: 2-3W typical
**Storage**: MicroSD card

**Limitations:**
- Limited RAM (avoid heavy additional services)
- Single-core CPU (Pi-hole only recommended)
- No WiFi (requires Ethernet connection)
- Perfect for: Pi-hole, lightweight DNS services
- Not suitable for: Docker, heavy applications

---

## Future Enhancements

### When Pi 5 Arrives

**Migration Plan:**
1. Set up Pi 5 with fresh Pi-hole installation
2. Export blocklists from Pi 1: `pihole -a -t`
3. Migrate dnsdist configuration
4. Transfer SSL certificates
5. Update Twingate resource to point to new IP
6. Test thoroughly before retiring Pi 1

**Pi 5 Advantages:**
- 16GB RAM (can run additional services)
- Much faster (8-core CPU)
- Better network performance
- Can handle more DNS queries/second

### Additional Services (Pi 5)

**Could Add:**
- Unbound (recursive DNS)
- Homepage dashboard
- Uptime Kuma monitoring
- Wireguard VPN
- Magic Mirror (migrate from Pi 2)

**Keep Pi 1 For:**
- Backup DNS server
- Network monitoring
- Simple sensor logging
- Or retire (512MB RAM very limited)

---

## Configuration Files Reference

**Important Files:**
```
/etc/dnsdist/dnsdist.conf                    # dnsdist DoT configuration
/etc/pihole/                                 # Pi-hole configuration directory
/etc/letsencrypt/live/pihole.jadedviber.com/ # SSL certificates
```

**Backup These Files:**
```bash
# From Pi-hole
sudo tar czf ~/pihole-backup-$(date +%Y%m%d).tar.gz \
  /etc/pihole/ \
  /etc/dnsdist/ \
  /etc/letsencrypt/

# Copy to Mac
scp pi@192.168.1.191:~/pihole-backup-*.tar.gz ~/backups/
```

---

## Quick Reference

```bash
# Connection Info
Local IP:        192.168.1.191
Hostname:        pihole.local
Web Admin:       http://192.168.1.191/admin
DoT Port:        8853
Domain:          pihole.jadedviber.com (DNS record needs update)

# SSH Access
ssh pi@pihole.local              # From CachyOS server
ssh pi@192.168.1.191             # Direct access

# Common Commands
pihole status                    # Check Pi-hole status
pihole restartdns                # Restart DNS service
pihole -up                       # Update Pi-hole
systemctl status dnsdist         # Check DoT service
dig @192.168.1.191 google.com    # Test DNS resolution
```

---

## Related Documentation

- [Home Lab Overview](../CLAUDE.md)
- [CachyOS Server Documentation](~/.claude/docs/homelab.md)
- [Twingate Setup](~/.claude/docs/homelab.md#3-twingate-connector)
- [Pi-hole Official Docs](https://docs.pi-hole.net/)
- [dnsdist Documentation](https://dnsdist.org/guides/dns-over-tls.html)
