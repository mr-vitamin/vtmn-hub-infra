# VTMN Hub — Infrastructure Reference

Historical reference date: 2026-07-28. Source corrections reviewed October 22, 2026 with the server off; no current installed version, account, address or service is verified. Linked scripts and historical instructions are not a validated rebuild procedure.

## Proxmox Host

- Address: `192.168.0.50` (web UI port 8006)
- Historical version description: Proxmox VE 9.1.0+, kernel 6.17.x; no exported installed inventory is available to confirm these now.
- Hardware: ASUS desktop board, 4 cores, 15GB RAM
- Network: `vmbr0` bridged to `nic0`, static `192.168.0.50/24`, gateway `192.168.0.1`

## Storage

| Name | Type | Purpose |
|---|---|---|
| `local` / `local-lvm` | dir / lvmthin | Boot disk — no longer used by service containers |
| `tank` | zfspool (mirror) | 2× 6TB WD Purple, ~5.45TB usable, redundant. All service container root disks live here. |
| `backup-tank` | dir (on tank) | Backup archive storage at `/tank/backups` |

## Containers

The table records historical addresses and service intent; it is not a current inventory or evidence of fixed DHCP reservations.

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

Provisioning defines eight unprivileged Debian 12 LXCs with DHCP on vmbr0. Only 101-106 specify `nesting=1,keyctl=1` for their Docker workloads; DNS 108 and syslog 107 have direct Linux setup scripts. These are source definitions, not verified running guest settings.

## Domain & TLS

- Intended LAN-only domain: `*.vtmn.internal`, resolved via container 108 (dnsmasq → NPM's IP for the wildcard)
- HTTPS via an internal CA (root cert generated once, installed on client devices' trust stores; wildcard cert issued for `*.vtmn.internal` and uploaded to NPM as a Custom Certificate)
- **NPM (105) is the documented front door.** Compose publishes administration port 81; an HTTPS management listener is not established by the committed configuration. Verify the actual scheme and management access separately.

## NPM Proxy Routes

| Domain | Forwards to | Auth model |
|---|---|---|
| `auth.vtmn.internal` | 192.168.0.124:9000 | N/A (Authentik itself) |
| `hub.vtmn.internal` | 192.168.0.56:3001 | Forward-auth (Authentik proxy provider) |
| `docs.vtmn.internal` | 192.168.0.176:3002 | Forward-auth |
| `inventory.vtmn.internal` | 192.168.0.175:8083 | Forward-auth |
| `drive.vtmn.internal` | 192.168.0.231:8443 | Native OIDC (Nextcloud `user_oidc` app) |

The NPM files in services/npm/nginx-snippets/ are complete historical exports with map/server configuration contexts, not paste-ready Advanced snippets. Auth and drive exports are missing. Read the [NPM context guide](../services/npm/README.md) and [application operations](APPLICATION-OPERATIONS.md); do not apply full exports.

## Identity (Authentik)

**Integrated source proposal:** The historical/candidate identity layout is separated locally; see [Authentik configuration guidance](../services/authentik/README.md). The server is unavailable and applied identity state is unverified. Historical inputs are outside the discovery mount; review-only candidates are not ready for deployment.

- Groups: `owners` (Owner/Admin), `operators` (Operators), plus Authentik's built-in `authentik Admins` (break-glass superuser only, not for daily use)
- Intended SSO integration recorded by the original reference:
  - **Nextcloud**: native OIDC. Provider-side configuration and supported secret injection require the installed-version gate; application-side user_oidc setup remains unverified.
  - **Wiki.js and Snipe-IT**: Authentik forward-auth plus separate local application accounts and permissions.
  - **Homepage**: Authentik forward-auth; no individual Homepage account is defined here.
- [Historical blueprints](../services/authentik/history/README.md) preserve previous OIDC/forward-auth transitions unchanged. Do not import them as a set.
- [Review-only identity candidates](../services/authentik/README.md) consolidate the three proxy applications/providers and one embedded-outpost assignment. Compose still mounts only blueprints/local; that directory intentionally has no project YAML pending compatibility and migration review.
- See [application operations](APPLICATION-OPERATIONS.md) and [local app permissions](../scripts/configure-app-permissions.md) for version-gated setup and independent authorization checks. No MFA, group policy or user migration is applied here.
- Determine the actual server/worker release and existing blueprint instances before selecting a supported import/instance procedure. Do not rely on discovery order or infer group/MFA enforcement from these files.

## Backups

- Documented job definition: daily at 02:00, all 8 containers, mode snapshot, compressed (zstd), stored on `backup-tank`
- Retention: 7 daily + 4 weekly
- Historical documentation reports a successful restore, but no dated archive/service/check record is committed; this is not current recovery verification.
- `backup-tank` shares `tank` with service data. See the [backup and disaster-recovery plan](BACKUP-RECOVERY-PLAN.md) for a proposed independent encrypted copy, coverage inventory and isolated restore/host-loss checklist. No new destination or restore has been implemented; server unavailable as of October 22, 2026.

## Centralized Logging

- All six service Compose stacks configure Docker syslog over UDP to `192.168.0.25:514`, tagged with the container name. Actual delivery and runtime sender identity are unverified while the server is off (October 22, 2026).
- The receiver template uses `/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log`; effective parsing, source attribution, local-versus-remote routing and permissions require verification. Restricted owner access is the documented intent, not demonstrated tamper resistance.
- See the [logging and lightweight monitoring plan](LOGGING-MONITORING-PLAN.md) for proposed source restrictions, remote-input ruleset, transport/rotation/capacity decisions, readiness checks and owner alerts. No monitoring platform or live configuration is deployed by that plan.

## Known Open Items

1. Historical firewall notes describe permissive defaults, not a current effective ruleset or proof that nothing is blocked. Any enforcement requires a separate network plan and verified independent console recovery.
2. Historical notes call Authentik older without an exact installed release; inventory, compatible migration/recovery planning and approval are required before upgrading. No upgrade or Redis removal is implemented. See the [version inventory and change gates](VERSION-MANAGEMENT.md).
3. No public-domain deployment is represented — LAN-only access is the intent (`*.vtmn.internal`) by design
4. Historical notes report DNS/CA enrollment only on the owner's device. Actual resolver distribution, CA trust and client enrollment are unverified; confirm addresses and trust before any approved onboarding.

## Integrated planning references

Read the [network access plan](NETWORK-SECURITY-PLAN.md), [CA custody/initialization guide](INTERNAL-CA.md), [governance recommendations](GITHUB-GOVERNANCE.md) and [portfolio evidence strategy](PORTFOLIO-EVIDENCE.md) alongside the source. These plans do not apply controls or establish runtime correctness. Homepage socket removal is deliberately deferred; see its [capability gate](../services/homepage/README.md).
