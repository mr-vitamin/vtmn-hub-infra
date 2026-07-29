#!/bin/bash
# Installs and configures rsyslog as a centralized log receiver for all
# service containers' Docker logs. Run inside container 107 (syslog).

set -e
apt-get update -qq
apt-get install -y -qq rsyslog

mkdir -p /var/log/remote
chmod 700 /var/log/remote

cat > /etc/rsyslog.d/10-remote.conf <<'EOF'
module(load="imudp")
input(type="imudp" port="514")
module(load="imtcp")
input(type="imtcp" port="514")

$template RemoteLogs,"/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?RemoteLogs
& stop
EOF

cat > /etc/logrotate.d/remote-logs <<'EOF'
/var/log/remote/*/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

systemctl restart rsyslog
systemctl enable rsyslog

echo "rsyslog listening on 514 (udp+tcp). Logs land in /var/log/remote/<hostname>/<container>.log"
echo ""
echo "Each service container needs a 'logging:' block added to its docker-compose.yml"
echo "services (see services/*/docker-compose.yml in this repo for the pattern):"
echo ""
echo "    logging:"
echo "      driver: syslog"
echo "      options:"
echo "        syslog-address: \"udp://<this-container-ip>:514\""
echo "        tag: \"{{.Name}}\""
echo ""
echo "This container is Owner/Proxmox-access-only — Operators should never be"
echo "granted access to it, since logs must be tamper-resistant."
