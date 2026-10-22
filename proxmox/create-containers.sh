#!/bin/bash
# Initial provisioning only; never reconciles, replaces or resumes existing guests.
set -euo pipefail
stage="checking prerequisites"
attempted="none"
trap 'rc=$?; if (( rc != 0 )); then
  printf "FAILED during %s (exit %s). Attempted writes: %s.\n" "$stage" "$rc" "$attempted" >&2
  printf "Do not retry blindly. Inspect actual guests/jobs, including failed attempts. No automatic cleanup was performed. See proxmox/SCRIPT-SAFETY.md.\n" >&2
fi' EXIT
die() { printf '%s\n' "$*" >&2; exit 1; }
[[ $# == 0 ]] || die "No positional arguments supported; see proxmox/SCRIPT-SAFETY.md."
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CHECK="$SCRIPT_DIR/script-safety.py"
for tool in python3 pvesh flock id; do
  command -v "$tool" >/dev/null || die "Required command missing: $tool"
done
[[ $(id -u) == 0 ]] || die "Run on the intended Proxmox host as root."
[[ -r "$CHECK" ]] || die "Required sibling file missing/unreadable: $CHECK"
# Advisory lock on this script inode; does not coordinate copies or other tools.
exec 9<"${BASH_SOURCE[0]}"
flock -n 9 || die "Another invocation of this script holds its lock."

for tool in pct pvesm ip timeout sleep; do
  command -v "$tool" >/dev/null || die "Required command missing: $tool"
done
TEMPLATE="${TEMPLATE:-local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst}"
DNS_ATTEMPTS="${DNS_ATTEMPTS:-30}"
DNS_INTERVAL="${DNS_INTERVAL:-2}"
[[ $TEMPLATE =~ ^local:vztmpl/[a-zA-Z0-9._-]+\.tar\.(zst|xz|gz)$ ]] ||
  die "TEMPLATE must name a local:vztmpl archive."
[[ $DNS_ATTEMPTS =~ ^[1-9][0-9]?$ ]] && (( DNS_ATTEMPTS <= 60 )) ||
  die "DNS_ATTEMPTS must be an integer from 1 to 60."
[[ $DNS_INTERVAL =~ ^[1-9][0-9]?$ ]] && (( DNS_INTERVAL <= 10 )) ||
  die "DNS_INTERVAL must be an integer from 1 to 10."
stage="checking all target VMIDs, bridge, ZFS storage and template before creation"
pvesh get /cluster/resources --type vm --output-format json | python3 "$CHECK" new-guests
ip link show dev vmbr0 >/dev/null
pvesh get /storage/tank --output-format json | python3 "$CHECK" root-storage
template_path=$(pvesm path "$TEMPLATE")
[[ -n $template_path && -f $template_path && -r $template_path ]] ||
  die "Template archive is not a readable regular file: $TEMPLATE"

create_guest() {
  stage="creating LXC $1"
  attempted="${attempted}; create $1"
  pct create "$@"
}
# 108: internal DNS resolver, started alone for manual DNS configuration.
create_guest 108 "$TEMPLATE" --hostname dns --cores 1 --memory 256 --swap 256 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:4 --unprivileged 1 --onboot 1
stage="starting DNS LXC 108"
attempted="${attempted}; start 108"
pct start 108
stage="waiting for a usable IPv4 address in DNS LXC 108"
DNS_IP=""
for (( attempt=1; attempt<=DNS_ATTEMPTS; attempt++ )); do
  if candidate=$(timeout --kill-after=2s 10s pct exec 108 -- ip -j -4 addr show dev eth0 |
      python3 "$CHECK" dns-address); then
    DNS_IP=$candidate
    break
  fi
  if (( attempt < DNS_ATTEMPTS )); then sleep "$DNS_INTERVAL"; fi
done
[[ -n $DNS_IP ]] || die "DNS readiness exhausted $DNS_ATTEMPTS attempts; guests 101-107 were not created."
printf 'DNS LXC IPv4: %s. An address does not prove dnsmasq is configured or resolving.\n' "$DNS_IP"
printf 'Configure scripts/setup-dns.sh separately and verify resolution from an intended client.\n'
stage="awaiting manual confirmation of DNS setup and resolution"
read -r -p "Type DNS-READY after checking DNS, or Ctrl-C to stop: " confirmation ||
  die "DNS confirmation was not received."
[[ $confirmation == DNS-READY ]] || die "DNS was not explicitly confirmed; stopping before 101-107."

# 101: Wiki.js
create_guest 101 "$TEMPLATE" --hostname wikijs --cores 1 --memory 1024 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:8 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 102: Snipe-IT
create_guest 102 "$TEMPLATE" --hostname snipeit --cores 1 --memory 1024 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:8 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 103: Homepage
create_guest 103 "$TEMPLATE" --hostname homepage --cores 1 --memory 512 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:6 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 104: Authentik
create_guest 104 "$TEMPLATE" --hostname authentik --cores 2 --memory 2048 --swap 1024 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:10 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 105: Nginx Proxy Manager
create_guest 105 "$TEMPLATE" --hostname npm --cores 1 --memory 1024 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:8 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 106: Nextcloud (large disk allocation for company file storage)
create_guest 106 "$TEMPLATE" --hostname nextcloud --cores 2 --memory 2048 --swap 1024 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:500 --features nesting=1,keyctl=1 \
  --unprivileged 1 --onboot 1

# 107: Centralized syslog
create_guest 107 "$TEMPLATE" --hostname syslog --cores 1 --memory 512 --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp --rootfs tank:30 --unprivileged 1 --onboot 1

stage="complete"
printf 'All containers created. Only DNS LXC 108 was started by this script.\n'
printf 'After inspecting DHCP addresses: install Docker only for services 101-106; configure rsyslog directly in 107.\n'
printf 'Apply the verified DNS address %s to 101-107 during separately approved setup.\n' "$DNS_IP"
printf 'No nameserver changes or guest reboots were performed. See proxmox/SCRIPT-SAFETY.md.\n'
