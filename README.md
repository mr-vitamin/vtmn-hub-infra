# VTMN Hub

A modular, self-hosted business collaboration platform running on Proxmox: centralized authentication (Authentik), shared file storage (Nextcloud), documentation (Wiki.js), inventory tracking (Snipe-IT), a central dashboard (Homepage), reverse proxy + HTTPS (Nginx Proxy Manager), internal DNS, and centralized logging.

This repo tracks the infrastructure-as-code side of the build: docker-compose files, Authentik SSO blueprints, NPM routing configs, and DNS/logging setup. It does **not** contain live secrets — see `.env.example` for what needs to be filled in, and `docs/INFRASTRUCTURE.md` for the full architecture writeup.

## Structure

```
services/
  wikijs/         Wiki.js + Postgres
  snipeit/        Snipe-IT + MariaDB
  homepage/       Dashboard
  authentik/      Identity provider + SSO blueprints
  npm/            Reverse proxy + forward-auth nginx snippets
  nextcloud/      File storage + MariaDB + Redis
  syslog/         Centralized logging config
  dns/            Internal DNS (dnsmasq) config
docs/
  INFRASTRUCTURE.md        Full architecture reference
  ONBOARDING-TEMPLATE.md   Template for new operator accounts
```

## Getting started (rebuilding from scratch)

1. Each `services/<name>/docker-compose.yml` is a working config — copy `.env.example` to `.env` in each directory that needs it and fill in real secrets (generate with `openssl rand -hex 32` or similar; never reuse a value across services)
2. Authentik blueprints in `services/authentik/blueprints/` are applied via `ak apply_blueprint <path>` inside the Authentik server container, or drop them in the bind-mounted `blueprints/local` directory for automatic discovery
3. NPM's forward-auth nginx snippets (`services/npm/nginx-snippets/`) get pasted into each proxy host's "Advanced" tab in the NPM UI — NPM doesn't support this via docker-compose directly
4. See `docs/INFRASTRUCTURE.md` for container IPs, network layout, and current known gaps

## Security notes

- All secrets in these files are placeholders (`${VAR_NAME}`) — the real values live only on the server and in the owner's password manager
- The internal CA's private key is never committed here — it lives only on the Proxmox host and must be regenerated (or securely transferred) if rebuilding elsewhere
- This repo assumes a LAN-only deployment on a private internal domain — adjust before exposing anything to the public internet
