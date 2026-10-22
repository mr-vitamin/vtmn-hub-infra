# VTMN Hub Infrastructure

A self-hosted collaboration platform and practical infrastructure lab built around Proxmox, Debian Linux containers, Docker, and centralized identity.

> **Availability:** The physical Proxmox server is powered off. This README describes repository configurations and historical documentation; it does not establish that any service is currently running. No live infrastructure access was used for this review.

## Project overview

VTMN Hub brings file sharing, documentation, asset inventory, and service navigation together behind internal DNS, HTTPS, and a central identity provider. Its modular design provides a practical environment for learning Linux administration, virtualization, networking, identity management, security architecture, container operations, and recovery.

This repository captures provisioning commands, service definitions, authentication blueprints, and operating procedures. It combines infrastructure as code with manual configuration steps; it is not a complete unattended deployment.

### Evidence and implementation status

| Status | What the repository supports |
|---|---|
| Configured in source | Eight LXC definitions, six Docker Compose stacks, Authentik providers, Nginx configurations, dnsmasq, rsyslog, internal certificate generation, and a Proxmox backup job. Files establish intended configuration, not successful deployment. |
| Historically documented | The [infrastructure reference](docs/INFRASTRUCTURE.md), dated July 28, 2026, describes deployed services and reports a test restore with data integrity verified. These are historical reports, not independently reproduced results from this review. |
| Pending in existing documentation | Restrictive firewall enforcement, an Authentik upgrade with a fresh backup, and DNS/CA setup for additional client devices. |
| Currently unverified | Service availability, installed versions, applied identity policies, certificate validity, backup freshness, and recoverability of the powered-off environment. |

## Architecture overview

Proxmox hosts eight Debian 12 LXC containers on a mirrored ZFS pool. The provisioning script creates unprivileged containers; the six application containers enable nesting and keyctl for Docker. DNS and syslog use Linux services directly.

All LXC interfaces attach to the Proxmox `vmbr0` bridge using DHCP. The reference records a single private LAN; VLAN segmentation and enforced inter-service isolation are not represented in these files.

```mermaid
flowchart TD
    Client["LAN client: internal DNS and CA trust"]
    DNS["dnsmasq: internal names resolve to NPM"]
    NPM["Nginx Proxy Manager: HTTPS termination"]
    Auth["Authentik: identity and proxy outpost"]
    Apps["Homepage / Wiki.js / Snipe-IT"]
    Drive["Nextcloud: file sharing and native OIDC"]
    Logs["rsyslog: centralized Docker logs"]
    PVE["Proxmox: eight Debian LXC containers"]
    ZFS["Mirrored ZFS tank: container disks"]
    Backup["backup-tank: archives on the same pool"]
    Client -->|DNS queries| DNS
    Client -->|HTTPS requests| NPM
    NPM -->|Authentication checks| Auth
    NPM -->|HTTP upstreams| Apps
    NPM -->|HTTP upstream| Drive
    Drive -.->|Documented OIDC integration| Auth
    Apps -->|Docker syslog over UDP| Logs
    Auth -->|Docker syslog over UDP| Logs
    Drive -->|Docker syslog over UDP| Logs
    NPM -->|Docker syslog over UDP| Logs
    PVE -->|Container storage| ZFS
    PVE -->|Scheduled snapshots to archives| Backup
    Backup ---|Same underlying pool| ZFS
```

- **Access path:** dnsmasq resolves the internal domain to Nginx Proxy Manager (NPM). NPM terminates HTTPS using an internally issued wildcard certificate and forwards requests to application ports over HTTP.
- **Identity:** Authentik provides the documented Nextcloud OIDC integration and proxy authentication for Homepage, Wiki.js, and Snipe-IT. Wiki.js and Snipe-IT still require application accounts and permissions.
- **Persistence:** Docker bind mounts and named volumes retain application data. Nextcloud provides shared files through its application; no separate NFS or SMB storage service is represented.
- **Operations:** Docker log drivers send logs to a dedicated rsyslog container. Proxmox backup configuration targets all eight containers.

See the [infrastructure reference](docs/INFRASTRUCTURE.md) for container IDs, recorded addresses, resource details, and proxy routes.

## Technology stack

| Technology or service | Purpose | Role within VTMN Hub |
|---|---|---|
| Proxmox VE | Virtualization and host management | LXC provisioning, storage registration, and scheduled backups |
| Debian 12 / LXC | Linux service environments | Eight unprivileged containers; six configured for Docker nesting |
| Docker / Docker Compose | Application packaging | Six service stacks with persistent storage and syslog logging |
| Authentik | Identity management | OIDC providers, forward-auth providers, and embedded proxy outpost |
| Nextcloud | Shared file access | File collaboration with MariaDB and Redis; documented native OIDC |
| Wiki.js | Documentation | Wiki with PostgreSQL; documented forward-auth access |
| Snipe-IT | Asset management | Inventory with MariaDB and documented Operator permissions |
| Homepage | Service dashboard | Internal service links, resource widgets, and custom styling |
| Nginx Proxy Manager | Reverse proxy | Internal HTTPS entry point, routing, and Authentik authentication checks |
| dnsmasq | Internal DNS | Wildcard internal resolution and upstream DNS forwarding |
| rsyslog / logrotate | Log collection and retention | UDP/TCP receiver, host/program log paths, and daily rotation |
| ZFS | Redundant storage | Mirrored pool for LXC root disks and local backup archives |
| OpenSSL | Internal PKI | Root CA and wildcard certificate generation |
| Proxmox backup tooling | Recovery | Snapshot-mode archives, zstd compression, and retention configuration |

Image tags describe requested images, not installed versions. Several stacks use `latest` or other mutable tags.

## Security architecture

### Identity, authentication, and authorization

The documentation defines `owners` and `operators` groups and reserves Authentik's built-in administrator group for break-glass access. These group assignments and restrictions are documented procedures; their complete configuration is not exported here.

- **Nextcloud:** An Authentik confidential OIDC provider and strict callback entries are included. The documentation describes first-login provisioning through `user_oidc`; the application-side settings are not fully captured.
- **Homepage, Wiki.js, and Snipe-IT:** NPM checks requests against Authentik's embedded outpost before forwarding them. This authenticates access through the proxy; it does not automatically create application identities or enforce application permissions.
- **Application permissions:** The [permission guide](scripts/configure-app-permissions.md) describes restricted Operator access. Snipe-IT Operators can manage inventory without deletion or user/admin privileges. Wiki.js permissions require reconciliation with the older OIDC instructions noted below.
- **MFA:** The [onboarding template](docs/ONBOARDING-TEMPLATE.md) asks for 2FA enrollment checks. The repository does not establish enforced MFA policies.

### Network access and HTTPS

The deployment is documented as LAN-only on an internal domain. Internal DNS and CA trust must be configured on each client or distributed through appropriate local network administration.

The [certificate script](scripts/create-internal-ca.sh) generates a root CA and wildcard server certificate for upload to NPM. HTTPS protects the client-to-proxy connection; the committed upstream routes use HTTP. A port named `8443` does not imply TLS: Nextcloud maps that host port to container port 80.

The [Proxmox firewall guide](proxmox/firewall-setup.md) explicitly records default ACCEPT policies. Restrictive enforcement remains pending. Published backend ports are not bound only to loopback, and the repository does not demonstrate rules preventing clients from bypassing proxy authentication through direct backend access.

### Secrets and administrative boundaries

[.env.example](.env.example) contains empty variables for database, application, and OIDC secrets. [.gitignore](.gitignore) excludes environment files and common private-key formats. No populated credentials or private-key files were identified in the 40 files reviewed at the source revision below. This is not a full Git history secret scan.

Real credentials, CA private keys, populated onboarding records, and recovery links belong outside version control. Environment placeholders in Authentik YAML require an explicitly verified substitution method; Docker Compose environment loading does not establish substitution inside separately mounted blueprint files.

Homepage mounts the Docker socket read-only. That filesystem mount flag does not establish read-only Docker API permissions; review whether socket access is necessary before rebuilding.

### Logging and accountability

All six application stacks configure Docker syslog logging to the dedicated receiver over UDP port 514. The receiver also accepts TCP and organizes logs by hostname and program. The setup script restricts the log directory and configures daily rotation with 30 retained rotations.

Owner-only access is documented, but immutable storage, authenticated/encrypted log transport, SIEM alerting, and complete host/security audit coverage are not established by these files. Centralized collection alone does not prove tamper resistance.

## Backup and recovery

The [backup job](proxmox/backup-job.sh) defines daily 02:00 snapshot-mode backups for containers 101–108, with zstd compression and retention of seven daily and four weekly restore points. The timezone of that schedule depends on the Proxmox host.

[Storage documentation](proxmox/storage-setup.md) places `backup-tank` at `/tank/backups` on the same mirrored pool used for container disks. The mirror provides disk redundancy; these local archives do not provide independent protection against loss of the host or pool. No off-host backup target is configured in the reviewed files.

The infrastructure reference reports a successful historical test restore, but includes no dated restore transcript or automated recovery test. The backup script recommends periodic restores to a separate container ID with a fresh network identity. Current backup contents, application consistency, and recovery times cannot be verified while the server is unavailable.

## Repository layout

```text
docs/                   Architecture reference and Operator onboarding template
proxmox/                LXC creation, ZFS storage, backup job, and firewall guidance
scripts/                Internal CA, DNS, syslog, and application permission setup
services/
  authentik/            Compose stack and identity blueprints
  dns/                  dnsmasq configuration
  homepage/             Dashboard Compose stack and configuration
  nextcloud/            Nextcloud, MariaDB, and Redis
  npm/                  Reverse proxy stack, notes, and exported Nginx configurations
  snipeit/              Snipe-IT and MariaDB
  syslog/               rsyslog receiver configuration
  wikijs/               Wiki.js and PostgreSQL
.env.example            Required secret variable names
```

Homepage's Kubernetes and Proxmox integration files contain sample/commented configuration. They are not evidence of deployed Kubernetes or an active Proxmox API integration.

## Rebuild workflow

These are planning steps for a future rebuild, not instructions to execute against the unavailable server. Resolve the configuration gaps below before treating the repository as reproducible.

1. Review the [storage procedure](proxmox/storage-setup.md) and adapt disk identifiers, template version, network settings, and container IDs to the target host. Storage creation requires deliberate disk selection.
2. Review [LXC provisioning](proxmox/create-containers.sh). It creates DNS first and pauses for configuration. Other dependencies include fixed backend addresses in service files, a functioning syslog receiver before logged stacks start, and Docker installation in the six application containers.
3. Place populated `.env` files in the relevant service directories using [.env.example](.env.example). Generate secrets in the format required by each application and keep them outside Git.
4. Copy Homepage configuration to the Compose bind-mount location, and create NPM's external `proxy` Docker network as described in its [README](services/npm/README.md).
5. Prepare the internal CA, client trust, DNS client settings, and NPM certificates/routes. Review exported Nginx files by context: they include full `map` and `server` blocks and should not be pasted wholesale into a proxy host's Advanced field.
6. Reconcile Authentik blueprint selection, paths, secret substitution, and outpost provider membership. Complete application-side OIDC or local account setup and confirm permissions.
7. Configure logging and the backup job, then perform an isolated restore test when infrastructure is available. Plan firewall enforcement with confirmed console access as the firewall guide requires.

## Known limitations and configuration gaps

| Area | Evidence and implication |
|---|---|
| Address stability | LXC creation uses DHCP; DNS, proxy providers, and log destinations embed recorded IPs. No DHCP reservations are captured. Reconcile addresses before deployment. |
| Nextcloud hostname | Compose trusted domains omit `drive.vtmn.internal`, although it is the documented proxy/OIDC hostname. Application-side trusted proxy and OIDC configuration is incomplete in source. |
| Authentik blueprint discovery | YAML files are under `blueprints/`, while Compose mounts `./blueprints/local`. Explicit placement is required for discovery. |
| Competing identity blueprints | Wiki.js OIDC and revert-to-forward-auth blueprints both set the Docs application's provider. Outpost blueprints also set provider lists. Do not apply all files blindly or infer a final state from discovery order. |
| Wiki.js permissions | The permission guide describes OIDC group mapping and self-registration, while the architecture and NPM notes describe forward-auth plus local accounts. The intended final account/permission procedure needs reconciliation. |
| NPM configuration format | The NPM guide calls the files Advanced-tab snippets, but they contain complete Nginx configuration blocks. Proxy records and certificate material are not provisioned by Compose alone. |
| Container feature description | The architecture reference says all eight LXCs enable nesting/keyctl; provisioning sets these only for the six Docker application containers. |
| Version maintenance | Documentation records a pending Authentik upgrade; mutable image tags do not identify the historically installed version or a tested upgrade target. |
| Client onboarding | Existing documentation says DNS and CA trust were configured only on the Owner's device. Broader client readiness is unverified. |
| Recovery independence | Backups share the production ZFS pool; off-host copies and measured recovery objectives are not documented. |

## Practical experience represented

The repository provides concrete examples of:

- **Virtualization and Linux administration:** resource allocation, unprivileged LXC provisioning, package installation, and systemd service configuration.
- **Networking and PKI:** bridged networking, internal DNS forwarding, reverse proxy routing, CA issuance, and client trust requirements.
- **Identity and access management:** OIDC and forward-auth integration, local application permissions, and Operator onboarding procedures.
- **Container and infrastructure management:** Compose dependencies, persistent data, service configuration, ZFS storage, and backup scheduling.
- **Security operations:** centralized logging, recovery planning, and identifying the limits of permissive firewall policies and proxy-only authentication.

These artifacts demonstrate implementation work and documented design decisions without claiming production hardening, availability, or complete automation.

---

**Review basis:** Repository revision `14eb27fafb4c43d49595a065daf91ce68d8c13cd`; documentation review on October 21, 2026. No server, internal address, or service endpoint was contacted.
