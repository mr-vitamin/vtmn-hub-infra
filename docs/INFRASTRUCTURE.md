# VTMN Hub — Infrastructure Reference

Last updated: 2026-07-28

## Proxmox Host

- Address: `192.168.0.50` (web UI port 8006)
- Version: Proxmox VE 9.1.0+, kernel 6.17.x
- Hardware: ASUS desktop board, 4 cores, 15GB RAM
- Network: `vmbr0` bridged to `nic0`, static `192.168.0.50/24`, gateway `192.168.0.1`

## Storage

| Name | Type | Purpose |
|---|---|---|
| `local` / `local-lvm` | dir / lvmthin | Boot disk — no longer used by service containers |
| `tank` | zfspool (mirror) | 2× 6TB WD Purple, ~5.45TB usable, redundant. All service container root disks live here. |
| `backup-tank` | dir (on tank) | Backup archive storage at `/tank/backups` |

## Containers

| VMID | Name | IP | Services | Ports | Compose file (this repo) |
|---|---|---|---|---|---|
| 101 | wikijs | 192.168.0.176 | Wiki.js + Postgres | 3002 | `services/wikijs/docker-compose.yml` |
| 102 | snipeit | 192.168.0.175 | Snipe-IT + MariaDB | 8083 | `services/snipeit/docker-compose.yml` |
| 103 | homepage | 192.168.0.56 | Homepage dashboard | 3001 | `services/homepage/docker-compose.yml` |
| 104 | authentik | 192.168.0.124 | Authentik server+worker+Postgres+Redis | 9000 | `services/authentik/docker-compose.yml` |
| 105 | npm | 192.168.0.31 | Nginx Proxy Manager | 80, 81 (admin), 443 | `services/npm/docker-compose.yml` |
| 106 | nextcloud | 192.168.0.231 | Nextcloud + MariaDB + Redis | 8443 | `services/nextcloud/docker-compose.yml` |
| 107 | syslog | 192.168.0.25 | rsyslog (centralized logging) | 514 udp/tcp | `services/syslog/10-remote.conf` |
| 108 | dns | 192.168.0.194 | dnsmasq (internal DNS) | 53 | `services/dns/dnsmasq.conf` |

All containers are Debian 12 LXC, unprivileged, `nesting=1,keyctl=1` (required for Docker-in-LXC).

## Domain & TLS

- Internal-only domain: `*.vtmn.internal`, resolved via container 108 (dnsmasq → NPM's IP for the wildcard)
- HTTPS via an internal CA (root cert generated once, installed on client devices' trust stores; wildcard cert issued for `*.vtmn.internal` and uploaded to NPM as a Custom Certificate)
- **NPM (105) is the front door.** Admin UI: `https://192.168.0.31:81`

## NPM Proxy Routes

| Domain | Forwards to | Auth model |
|---|---|---|
| `auth.vtmn.internal` | 192.168.0.124:9000 | N/A (Authentik itself) |
| `hub.vtmn.internal` | 192.168.0.56:3001 | Forward-auth (Authentik proxy provider) |
| `docs.vtmn.internal` | 192.168.0.176:3002 | Forward-auth |
| `inventory.vtmn.internal` | 192.168.0.175:8083 | Forward-auth |
| `drive.vtmn.internal` | 192.168.0.231:8443 | Native OIDC (Nextcloud `user_oidc` app) |

Forward-auth nginx snippets live in `services/npm/nginx-snippets/` — pasted into each proxy host's "Advanced" tab in the NPM UI (NPM doesn't expose this via docker-compose directly).

## Identity (Authentik)

- Groups: `owners` (Owner/Admin), `operators` (Operators), plus Authentik's built-in `authentik Admins` (break-glass superuser only, not for daily use)
- SSO integration:
  - **Nextcloud**: native OIDC — see `services/authentik/blueprints/nextcloud-sso.yaml`
  - **Wiki.js, Snipe-IT, Homepage**: forward-auth via Authentik's embedded proxy outpost — see `services/authentik/blueprints/forward-auth-setup.yaml` and `homepage-forward-auth.yaml`. These apps still need their own separate local accounts for individual users (forward-auth gates network access, not per-app identity).
- Blueprints are applied via `ak apply_blueprint <path>` inside the Authentik server container, or automatically picked up from `/blueprints/local` (bind-mounted from `./blueprints/local` in the compose file) on Authentik's periodic discovery cycle.

## Backups

- Scheduled job: daily at 02:00, all 8 containers, mode snapshot, compressed (zstd), stored on `backup-tank`
- Retention: 7 daily + 4 weekly
- A test restore has been performed and verified data integrity (see project history — not automated, should be repeated periodically)

## Centralized Logging

- All 6 service containers ship Docker container logs via the `syslog` logging driver to container 107 (rsyslog), organized under `/var/log/remote/<hostname>/<container>.log`
- Operators have no access to this container — it's Proxmox/Owner-only infrastructure

## Known Open Items

1. Proxmox firewall is enabled but set to a permissive default policy (not actively blocking) — flipping to enforce needs to be done deliberately, at the console, to avoid remote lockout risk
2. Authentik is running an older version — a planned upgrade (with a fresh backup first) is still pending
3. No real public domain — everything is internal-only (`*.vtmn.internal`) by design
4. DNS resolution and CA trust are currently only configured on the Owner's own device — other devices/operators need the same setup (router DHCP DNS pointed at 192.168.0.194, and the CA root cert installed) before they can reach the platform by hostname over HTTPS
