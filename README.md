# VTMN Hub

A modular, self-hosted business collaboration platform running on Proxmox: centralized authentication (Authentik), shared file storage (Nextcloud), documentation (Wiki.js), inventory tracking (Snipe-IT), a central dashboard (Homepage), reverse proxy + HTTPS (Nginx Proxy Manager), internal DNS, and centralized logging.

This repo tracks the infrastructure-as-code side of the build: docker-compose files, Authentik SSO blueprints, NPM routing configs, and DNS/logging setup. It does **not** contain live secrets — see `.env.example` for what needs to be filled in, and `docs/INFRASTRUCTURE.md` for the full architecture writeup.

## Structure

```
proxmox/
  create-containers.sh    Exact pct create commands for all 8 LXC containers
  storage-setup.md         ZFS tank pool + backup-tank storage setup
  backup-job.sh            Scheduled daily backup job (all containers)
  firewall-setup.md        Current firewall state + how to enforce it safely
scripts/
  create-internal-ca.sh          Generates the internal CA + wildcard cert
  setup-dns.sh                   Installs/configures the internal DNS resolver
  setup-syslog.sh                Installs/configures centralized log receiver
  configure-app-permissions.md   Wiki.js/Snipe-IT Operator permission setup
services/
  wikijs/         Wiki.js + Postgres
  snipeit/        Snipe-IT + MariaDB
  homepage/       Dashboard (includes actual config/*.yaml — bookmarks, layout, etc.)
  authentik/      Identity provider + SSO blueprints
  npm/            Reverse proxy + forward-auth nginx snippets (see its README for gotchas)
  nextcloud/      File storage + MariaDB + Redis
  syslog/         Centralized logging config (rsyslog)
  dns/            Internal DNS (dnsmasq) config
docs/
  INFRASTRUCTURE.md        Full architecture reference
  ONBOARDING-TEMPLATE.md   Template for new operator accounts
```

## Getting started (rebuilding from scratch)

1. Set up storage first (`proxmox/storage-setup.md`), then create all containers (`proxmox/create-containers.sh` — read it, it has an ordering dependency on the DNS container)
2. Install Docker in each container, then bring up each `services/<name>/docker-compose.yml` — copy `.env.example` to `.env` and fill in real secrets first (generate with `openssl rand -hex 32` or similar; never reuse a value across services)
3. Generate the internal CA and cert (`scripts/create-internal-ca.sh`), upload to NPM as a Custom Certificate, install the root CA on every device that needs HTTPS access
4. Authentik blueprints in `services/authentik/blueprints/` are applied via `ak apply_blueprint <path>` inside the Authentik server container, or drop them in the bind-mounted `blueprints/local` directory for automatic discovery
5. NPM's forward-auth nginx snippets (`services/npm/nginx-snippets/`) get pasted into each proxy host's "Advanced" tab in the NPM UI — see `services/npm/README.md` for a gotcha that bit us twice
6. Set up centralized logging (`scripts/setup-syslog.sh`) and the backup job (`proxmox/backup-job.sh`)
7. Configure per-app Operator permissions (`scripts/configure-app-permissions.md`)
8. See `docs/INFRASTRUCTURE.md` for container IPs, network layout, and current known gaps

## Security notes

- All secrets in these files are placeholders (`${VAR_NAME}`) — the real values live only on the server and in the owner's password manager
- The internal CA's private key is never committed here — it lives only on the Proxmox host and must be regenerated (or securely transferred) if rebuilding elsewhere
- This repo assumes a LAN-only deployment on a private internal domain — adjust before exposing anything to the public internet
