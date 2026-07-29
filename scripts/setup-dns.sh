#!/bin/bash
# Installs and configures dnsmasq to resolve *.vtmn.internal to NPM's IP,
# forwarding everything else upstream. Run inside container 108 (dns).
#
# NPM_IP should be the IP of your Nginx Proxy Manager container (105 in this
# build, 192.168.0.31). Change it below if different.

set -e
NPM_IP="192.168.0.31"
UPSTREAM_DNS_1="192.168.0.1"   # your router, or another upstream
UPSTREAM_DNS_2="1.1.1.1"       # public fallback

apt-get update -qq
apt-get install -y -qq dnsmasq

cat > /etc/dnsmasq.conf <<EOF
# Resolve all *.vtmn.internal to NPM
address=/vtmn.internal/${NPM_IP}

# Forward everything else upstream
server=${UPSTREAM_DNS_1}
server=${UPSTREAM_DNS_2}

listen-address=0.0.0.0
bind-interfaces
EOF

systemctl restart dnsmasq
systemctl enable dnsmasq

echo "dnsmasq running. Test with:"
echo "  nslookup auth.vtmn.internal 127.0.0.1   (should return ${NPM_IP})"
echo "  nslookup google.com 127.0.0.1           (should resolve normally)"
echo ""
echo "IMPORTANT — for other devices/operators to actually use this:"
echo "  1. Point your router's DHCP DNS setting at this container's IP, OR"
echo "  2. Set each device's DNS manually to this container's IP"
echo "Only the machine that had this done manually during initial setup will"
echo "resolve *.vtmn.internal until one of the above is done network-wide."
