# Version inventory and controlled upgrade plan

**Planning only — October 22, 2026.** Finding OPS-001 remains open. The server is off. This inventory records committed references at master 14eb27fafb4c43d49595a065daf91ce68d8c13cd; it does not identify installed images or application/database versions. No registry image was pulled, digest resolved, tag changed, service upgraded or Redis removed.

## Configured image inventory

All 13 service references across six Compose files use tags, not digests. There are nine distinct configured references: six occurrences of latest and seven moving release-family/variant tags. Even a full release tag can be republished; a family tag does not lock an exact patch or image build.

| Compose file | Service | Configured image | Tag scope | Installed image/app version |
|---|---|---|---|---|
| services/authentik/docker-compose.yml | postgresql | postgres:15 | Major family | Unknown |
| services/authentik/docker-compose.yml | redis | redis:alpine | Variant / moving release | Unknown |
| services/authentik/docker-compose.yml | server | ghcr.io/goauthentik/server:latest | Latest | Unknown |
| services/authentik/docker-compose.yml | worker | ghcr.io/goauthentik/server:latest | Latest | Unknown |
| services/wikijs/docker-compose.yml | db | postgres:15 | Major family | Unknown |
| services/wikijs/docker-compose.yml | wiki | ghcr.io/requarks/wiki:2 | Major family | Unknown |
| services/snipeit/docker-compose.yml | snipeit | snipe/snipe-it:latest | Latest | Unknown |
| services/snipeit/docker-compose.yml | snipeit-db | mariadb:10.11 | Release series | Unknown |
| services/homepage/docker-compose.yml | homepage | ghcr.io/gethomepage/homepage:latest | Latest | Unknown |
| services/npm/docker-compose.yml | npm | jc21/nginx-proxy-manager:latest | Latest | Unknown |
| services/nextcloud/docker-compose.yml | db | mariadb:10.11 | Release series | Unknown |
| services/nextcloud/docker-compose.yml | redis | redis:alpine | Variant / moving release | Unknown |
| services/nextcloud/docker-compose.yml | app | nextcloud:latest | Latest | Unknown |

The historical [infrastructure reference](INFRASTRUCTURE.md) calls Authentik old but provides no exact installed release. Its Proxmox/kernel and Debian descriptions are historical too. Do not convert those statements into a current support/CVE finding. DNS/syslog use Linux packages outside these Compose files; inventory their package versions and Docker/Compose, guest OS, host kernel/Proxmox separately before a related upgrade. They are not extra Docker images.

Repository rebuild instructions describe initial setup, not a safe upgrade procedure. A generic pull/recreate against these mutable references can change database/application state; it is not approved by this plan.

## Capture actual state before selecting targets

When the server is available, obtain a separately authorized read-only inventory using narrowly selected fields, application admin/version views and version-matched database inspection. Avoid publishing whole container-inspect objects, rendered Compose environments or .env contents.

For each service, privately record:

- Guest/architecture, actual service directory, Compose file/overrides/profile/project and desired configured reference.
- Running container's configured image string and immutable image ID; relevant repository digest(s) if available; platform/manifest relationship. A local image ID is not interchangeable with a registry manifest digest, and a digest list must be matched to the correct repository/platform.
- Actual application/server version and database schema/migration status. Persistent code/data or a partially completed migration can make these differ from the image label.
- Effective OS/base variant, dependencies, ports/mounts, config schema, build provenance and resource use. Capture app versions from each Authentik server/worker and check agreement rather than assume matching tags mean matching content.
- Latest verified independent recovery point, required credentials/keys and known-compatible prior images/software. Record “unavailable” for missing digests or evidence instead of guessing from the registry's current tag.
- Observation time, source/method and sanitized evidence. Installed versions remain unknown until that evidence exists.

No command needs to start, pull, restart, recreate or migrate a service to collect this inventory. Any method requiring those effects must stop for separate approval.

## Pinning policy — proposed, no replacements selected

1. Start from the **actual known-good installed state** and capture recovery artifacts before deciding whether to reproduce it or upgrade. Freezing an unknown currently resolved latest tag is not an installed-state inventory.
2. Select a maintained, compatible target from the service's official release notes and supported upgrade path. Review security notices for the exact version/build and relevant exposure; neither “latest” nor a digest proves vulnerability status.
3. Prefer a human-readable full release/variant plus a verified registry digest for reproducibility. Conceptual syntax is repository:release@sha256:digest; no placeholder is an installable pin here. Verify publisher/repository, supported architecture and whether the selected digest is a multi-platform index or platform manifest. Do not invent hashes.
4. Preserve relevant image variant/entrypoint behavior. For example, do not switch Nextcloud's web-server/FPM variant or database distribution while changing a version. Choose version-matched Compose/schema changes rather than blindly downloading over local configuration.
5. If only release tags are initially practical, record the resolved immutable identity and tag-mutability limitation. Schedule a reviewed follow-up; do not call it fully reproducible. Cache/recover needed known-good images through a separately approved process before later pruning.
6. Change one application stack or one required migration step at a time, with a separate reviewable diff. Match Authentik server and worker release/digest. Shared tag spelling does not require upgrading unrelated Wiki.js and Authentik database instances together.
7. Pinning is not an update policy. Propose a monthly manual review of vendor releases/security notices and faster review of relevant advisories, then approve/test updates deliberately. No automatic updater, recurring task, image pruning or package installation is introduced.

Docker documents [tag mutability and digest pinning](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions). Use a verified digest as content identity, not as proof of trust or long-term registry availability.

## Service-specific migration gates

| Component | Required decision and rehearsal before any change |
|---|---|
| Authentik | Determine actual installed release, stored migrations, outposts/blueprints, flow/policy behavior and supported PostgreSQL. Follow every documented release-train step, applying its supported patch level and release-specific Compose requirements. Match server/worker. Test real provider/outpost/app permissions against restored data; source YAML parsing is not an Authentik migration test. |
| Authentik Redis topology | Preserve current Redis service/settings until the actual start/target and every intermediate step are known. Release 2025.10 removed Redis and changed PostgreSQL workload; crossing that boundary needs the matching release's migration procedure and measured database resources. Do not infer installed version from a Redis-era Compose file. |
| Nextcloud | Follow its supported Docker update route one major at a time, with the required current-major maintenance release and completed background migrations before the next hop. Verify user_oidc/app, PHP/image variant, MariaDB, Redis, trusted proxy and canonical URL compatibility. Match database, files and config at each checkpoint. |
| Wiki.js | Identify the installed Wiki.js release, schema and asset storage. Compare the selected release's migration/database requirements; a :2 tag is not a tested upgrade route. No speculative cross-major migration is selected here. |
| Snipe-IT | Use container-image/release-specific instructions; preserve APP_KEY, .env, uploads and MariaDB recovery together. Verify authorization and stored asset data after migrations; do not apply Git-install updater commands inside an image deployment simply because the generic guide includes them. |
| NPM | Preserve data/database, certificate keys, includes and host objects. Review release-specific generated-Nginx and migration changes; test all five routes, auth destinations and TLS in isolation. Do not use a generic pull/recreate sequence as database rollback. |
| Homepage | Check release-specific config/widget/allowed-host behavior with the actual config bind. Homepage socket removal is deferred in this candidate pending effective-config/consumer inventory; an upgrade does not authorize changing that capability decision or adding integrations. |
| PostgreSQL (two independent instances) | Compare app support, required extensions/roles/collation and actual database version. A major data-format change requires a supported migration such as compatible dump/restore or pg_upgrade, rehearsed separately. Do not mount the existing data directory into an arbitrary newer major image. |
| MariaDB (two independent instances) | Confirm actual version, app support and the specific start/target upgrade route and image behavior. Plan required system-table checks/upgrades, collation/SQL compatibility and backups. Do not treat 10.11 as a frozen patch or assume arbitrary major-version downgrade works. |
| Redis (two independent stacks) | Inventory actual release and persistence/session/cache requirements. Preserve compatibility with the dependent app; Authentik's later topology change does not justify deleting Nextcloud Redis or changing its REDIS_HOST. |

Primary guidance reviewed on October 22, 2026; recheck the exact supported versions before implementation:

- [Authentik upgrade sequence and downgrade warning](https://docs.goauthentik.io/install-config/upgrade) and [2025.10 Redis change](https://docs.goauthentik.io/releases/2025.10/).
- [Nextcloud server upgrade constraints](https://docs.nextcloud.com/server/latest/admin_manual/maintenance/upgrade.html) and [Docker-image instructions](https://github.com/nextcloud/docker). The server manual also points Docker users to installation-method guidance; no archive updater is selected here.
- [PostgreSQL data migration guidance](https://www.postgresql.org/docs/current/upgrading.html) and [MariaDB upgrade utility guidance](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-upgrade). These do not establish app compatibility. PostgreSQL's possible direct major upgrade must not be confused with Nextcloud/Authentik's sequential application requirements.
- [Snipe-IT upgrade cautions](https://snipe-it.readme.io/docs/upgrading) and [NPM release-specific upgrade notes](https://nginxproxymanager.com/upgrading/). Consult the selected Wiki.js/Homepage/Redis release's own notes once exact versions are known.

No “newest” target, supported status, specific CVE or safe hop list is inferred for the unavailable installation.

## Future approval and verification checklist

Every execution step below is pending and requires separate approval.

### Before a candidate change

- Confirm installed identities/versions/schema and intended target, architecture, app/database compatibility and complete ordered hops. Record source links, breaking changes and any release-specific resource/config requirements.
- Prove a usable independent recovery point for app files, database, configuration, credentials/CA and prior software. The separate backup plan is a proposal; do not treat it as implemented. The committed [storage reference](../proxmox/storage-setup.md) places current local archives on the same pool.
- Establish console/owner recovery, required outage window, safe test VMIDs/storage and isolation of clone NICs and production-facing mounts before first boot. The single historical four-core/~15 GB host may not have capacity for production plus a full duplicate. Defer or approve separate resources rather than overcommit or delete production.
- Prepare a narrow proposed Compose/config diff. Compare it with the exact selected release's schema and existing secrets/mounts/ports. A config parse may require interpolation; use a restricted environment and dummy values offline, never render real secrets into reports.
- Record a stop/rollback decision for each migration. Do not combine a host upgrade, network enforcement, credential rotation and application major upgrade into one maintenance action.

### Isolated rehearsal

- Start from restored known-good data/software in a disposable isolated environment, with backups/sources protected and no production callbacks, email, webhook, mount or scheduled-job side effects.
- Validate that a baseline app/data/login test passes before upgrading. Test each required hop and its background migrations before continuing; stop on unexplained schema/errors, failed permission checks, unavailable keys or excessive resource use.
- Test DB records/files/uploads, allowed and denied accounts, SSO/outpost/OIDC flows, NPM generated config/TLS/routes, cron/background work and log delivery for the stack affected. Check configured logging-driver initialization separately from remote receiver reachability.
- Measure memory/CPU/disk growth and migration duration. Record expected outage/data-loss bounds, actual versions/digests, migration state and limitations. Success of one app/hop is not verification of all stacks.
- Rehearse restoring the prior **data + config + app image + database version** together. Preserve any prior media and recovery material. A successful forward migration alone is not proof of rollback.

### After separate rollout approval

- Reconfirm production baseline has not drifted; repeat backup/console gates, choose exact reviewed images and follow only the rehearsed version-specific steps. No generic commands are authorized by this document.
- Verify new installed identities, completed migrations, data, auth/permissions, URLs/certs, logs, app background jobs and resource behavior. Retest after an approved restart where relevant.
- Stop/rollback on failed acceptance using the matched recovery set, with a conscious decision about writes since the backup. Never point an old image at a newly migrated database and call it a revert. Authentik/Nextcloud do not support ordinary downgrade; recovery requires an appropriate earlier backup.
- Record the exact resulting references and immutable identities; retain recovery artifacts until acceptance, then consider cleanup only with separate approval. Do not automatically prune images/volumes or overwrite the last known-good snapshot.

## Upgrade/rollback record and current status

For each eventual change, record observed start image/app/DB versions, selected targets/digests/platform, required hop sequence and vendor evidence, backup/recovery-set identity, console/isolation validation, planned/actual outage, rehearsal/rollback outcomes, production approval, resulting versions, residual issues and next review date. Keep credentials and raw dumps out of GitHub.

**Current record: no installed inventory, target selection, image pull, migration, upgrade or rollback exercise performed.** Only the configured table and this plan are prepared. OPS-001 is not fully remediated while Compose still uses mutable tags and live state remains unknown.

Rollback of this package is documentation-only: discard/revert the isolated proposal. It neither changes nor restores any runtime image/database. Future runtime rollback must use the separately approved recovery procedure and verified matched artifacts.
