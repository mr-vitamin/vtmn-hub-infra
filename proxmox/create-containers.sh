#!/bin/bash
# Recreates all 8 VTMN Hub LXC containers on a Proxmox host.
# Run on the Proxmox host itself as root. Assumes:
#   - A "tank" ZFS storage pool already exists (see storage-setup.md)
#   - The debian-12-standard template is already downloaded to local storage
#     (pveam download local debian-12-standard_12.12-1_amd64.tar.zst, or
#     whatever current version `pveam available` shows)
#   - Container 108 (dns) should be created and its dnsmasq configured (see
#     scripts/setup-dns.sh) BEFORE creating 101-107, so their --nameserver
#     can point at it. Order below reflects that.

TEMPLATE="local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"

# 108: internal DNS resolver (create first)
pct create 108 "$TEMPLATE" --hostname dns --cores 1 --memory 256 --swap 256 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:4 --unprivileged 1 --onboot 1
pct start 108
sleep 5
DNS_IP=$(pct exec 108 -- ip -4 addr show eth0 | grep -oP 'inet \K[\d.]+')
echo "DNS container IP: $DNS_IP -- configure dnsmasq (scripts/setup-dns.sh) before continuing"
read -p "Press enter once DNS is configured and confirmed working..."

# 101: Wiki.js
pct create 101 "$TEMPLATE" --hostname wikijs --cores 1 --memory 1024 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:8 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 102: Snipe-IT
pct create 102 "$TEMPLATE" --hostname snipeit --cores 1 --memory 1024 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:8 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 103: Homepage
pct create 103 "$TEMPLATE" --hostname homepage --cores 1 --memory 512 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:6 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 104: Authentik
pct create 104 "$TEMPLATE" --hostname authentik --cores 2 --memory 2048 --swap 1024 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:10 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 105: Nginx Proxy Manager
pct create 105 "$TEMPLATE" --hostname npm --cores 1 --memory 1024 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:8 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 106: Nextcloud (large disk allocation for company file storage)
pct create 106 "$TEMPLATE" --hostname nextcloud --cores 2 --memory 2048 --swap 1024 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:500 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 107: Centralized syslog
pct create 107 "$TEMPLATE" --hostname syslog --cores 1 --memory 512 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:30 --unprivileged 1 --onboot 1

echo "All containers created. Start each, install Docker (see services/*/docker-compose.yml),"
echo "then set --nameserver $DNS_IP on 101-107 and reboot each:"
echo "  for id in 101 102 103 104 105 106 107; do pct set \$id --nameserver $DNS_IP; pct reboot \$id; done"
