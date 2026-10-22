# Backup and disaster-recovery plan

**Proposal only — October 22, 2026.** Findings BKR-001 and BKR-002 remain open. The server is off. No archive, media, key, backup job, restore or recovery result was inspected live or changed.

## Documented baseline and failure domains

The [storage definition](../proxmox/storage-setup.md) places service disks on a two-disk ZFS mirror named tank. backup-tank is directory storage at /tank/backups on that same pool. A separate storage name is not a separate copy. The mirror can tolerate some disk failures; it does not provide independent protection from complete pool loss, theft, destructive host access or a shared disaster.

The [backup script](../proxmox/backup-job.sh) defines daily 02:00, IDs 101-108, snapshot mode, zstd and keep-daily=7,keep-weekly=4. Preserve that local archive strategy. The scheduler timezone, actual job, successful archives, capacity and retention are unverified. The linked script now contains the integrated safety checks; do not execute it as an inspection step or assume it has been applied to the host. Read the [script safety/recovery guide](../proxmox/SCRIPT-SAFETY.md) and satisfy its version/capacity/recovery gates first.

The [infrastructure reference](INFRASTRUCTURE.md) reports a historical successful test restore without a dated archive/service/check record. That report is not a reproducible test result or proof of current recoverability. Snapshot mode does not guarantee zero disruption or application-consistent databases. Restore-point age must be measured, not inferred from a daily schedule.

## Proposed independent encrypted copy

A practical first option is an **approved, separate removable drive**, using LUKS encryption and a Linux-compatible filesystem selected for the recovery environment. It avoids a new always-on server or enterprise platform. Linux [dm-crypt/LUKS documentation](https://docs.kernel.org/admin-guide/device-mapper/dm-crypt.html) describes the encryption foundation; installed tooling, format/version and recovery compatibility must be established before implementation. No tool is installed or encryption initialized here.

Hardware does not currently have a verified identity, capacity or availability. Before any future provisioning, identify the exact model/serial/capacity and existing contents, check whether it is truly outside tank, agree on secure storage, and obtain explicit approval for any formatting or overwrite. A label, USB device name or assumed empty drive is not enough.

Proposed operator cycle, after separate approval:

1. Select a completed, successful and consistent archive set plus its recovery bundle; never copy an archive still being written or pruned. Record VMIDs, archive identities, capture times, file sizes and software versions.
2. Verify the expected encrypted media is actually mounted/unlocked at the intended destination and has capacity before any write. A missing mount must fail closed rather than write into a directory on tank. Do not add the removable destination to the existing unattended schedule blindly.
3. Copy into a new generation without mirroring deletions or overwriting the last verified generation. Include manifests, job logs and application-consistent material from the same recovery point. Mark the generation incomplete until all objects are verified.
4. Compare source/destination checksums and completeness, then independently reopen the encrypted media on a compatible recovery environment and recheck. A copy command's exit code alone does not prove the stored copy is readable.
5. Flush and safely unmount/lock through a validated procedure; physically disconnect and store separately from the host. Record media ID, generation date, verification status and next copy due without publishing secrets.

Encryption protects data while locked, not against root access, deletion or ransomware while the media is mounted. A disconnected copy reduces that exposure. A single external disk kept beside the server still shares theft/fire risk. If suitable second media and secure separate storage are later approved, rotate copies with one elsewhere. This project does not yet claim a 3-2-1 strategy or off-site protection.

Capacity must be based on measured full archive sizes, actual data growth, recovery bundle/dump sizes, temporary copy space and retained generations. Nextcloud's provisioned 500 GB disk is not measured used space or compressed archive size. zstd is not a guaranteed ratio; independent full copies are not assumed deduplicated. Do not purchase a capacity or delete old generations based solely on allocation figures.

## Recovery objectives and retention — provisional

| Area | Proposed planning target | Limit / required decision |
|---|---|---|
| Local recovery | Preserve daily 02:00 and current 7-daily/4-weekly settings | A missed/failed job extends loss exposure. Prune rules do not promise a fixed count of distinct files. Confirm scheduler timezone and actual logs. |
| Independent copy | Weekly manual copy, plus after important configuration/credential changes | Provisional maximum loss target is about one week only when copies succeed; missed cycles and older app-consistent points worsen it. Choose more frequent copies if data value requires it. |
| Independent retention | Initially aim for four verified weekly generations, capacity permitting | No deletion or automated prune is authorized. Preserve the last known-good copy; approve retention only after sizing and verification. |
| Recovery time | Aim to demonstrate critical services within one planned recovery day after working hardware, media, keys and compatible software are available | An exercise target, not an SLA. Procurement, operator availability and unknown data sizes can extend total outage. Measure actual elapsed time. |

Agree on acceptable data loss and recovery order before choosing a final schedule. Independent recovery objectives are based on the latest successful independent copy and its data timestamp, not the fresher archive that would be lost with tank.

## Recovery coverage and consistency inventory

A Proxmox LXC archive and a Docker bind mount are different layers. A path bind-mounted into Docker can be inside the LXC root disk and captured there. An LXC host bind/device mount or excluded extra mount may not be captured. Inventory actual rootfs, mp entries, backup flags, symlinks and external storage before claiming coverage. Current [Proxmox backup guidance](https://github.com/proxmox/pve-docs/blob/master/vzdump.adoc) describes these exclusions; confirm the installed version.

| Component | Committed persistence / recovery material | What must be verified before backup acceptance |
|---|---|---|
| Wiki.js, 101 | /opt/wiki/db → PostgreSQL data; Compose and effective environment | Database consistency, roles/pages and any configured uploads/external asset storage. Only the DB bind is committed; discover other data before claiming all wiki content is covered. |
| Snipe-IT, 102 | Named snipeit_data and snipeit_db volumes | Resolve actual volume locations inside the LXC; include uploads and MariaDB data together with the existing SNIPEIT_APP_KEY and DB secrets. Do not regenerate the app key. |
| Homepage, 103 | /opt/homepage/config | Actual runtime configuration, custom assets and any widget credentials; committed examples are not the only possible live data. |
| Authentik, 104 | ./database, ./media, ./custom-templates and ./blueprints/local relative to its actual service directory | PostgreSQL, uploaded media, effective blueprints/config, AUTHENTIK_SECRET_KEY, database credentials, signing/certificate material and stored identity/outpost/policy state. Source blueprints alone cannot recover database state. |
| NPM, 105 | ./data and ./letsencrypt relative to the service directory | Actual NPM database, proxy-host objects, custom includes, custom certificate/leaf private-key material and generated-object mapping. Exported Nginx files alone are insufficient. |
| Nextcloud, 106 | /opt/nextcloud/db, /opt/nextcloud/html, /opt/nextcloud/data | MariaDB and files from a coordinated point, config.php, installed app/version state, trusted domains/proxies and user_oidc settings/secrets. If server-side encryption or external storage is used, inventory its keys/destinations too; neither is established by this repo. |
| Syslog, 107 | /etc/rsyslog.d/10-remote.conf, rotation settings, /var/log/remote | Actual config, ownership and retained logs if required; do not confuse a config-only export with log preservation. |
| DNS, 108 | /etc/dnsmasq.conf and effective service/network configuration | Resolver/upstream settings, stable address, actual client/DHCP distribution and any extra local records. |
| Proxmox host / router | Actual storage.cfg, guest definitions, bridge/gateway/NIC identities, firewall options, job definitions, versions and router reservations | A protected host/bootstrap bundle outside tank. LXC archives are not a complete host-OS/router backup; include secure metadata needed to rebuild access without copying it blindly onto a different host. |
| CA / client trust | Existing ca.key, ca.crt, vtmn-internal.key, vtmn-internal.crt, chain, any serial/issuance material and client trust instructions | Locate actual custody; script output is relative to invocation directory, so host location is not guaranteed. Preserve the CA identity; do not regenerate it during recovery or upload the CA private key to NPM. |
| Credentials / software | Effective .env/config secrets, SNIPEIT_APP_KEY, AUTHENTIK_SECRET_KEY, OIDC/DB secrets, privileged recovery access, image versions/digests and any needed offline software | .env.example is incomplete by design. Preserve actual existing values securely; recover known compatible software without an automatic latest-tag pull or database migration. |

The Homepage Docker socket mount is a runtime API endpoint, not backup data; preserving the real dashboard configuration does not require copying that socket. Its removal is explicitly deferred in this candidate pending real consumer/configuration inventory.

Redis has no committed persistent bind in the shown Authentik/Nextcloud stacks. Do not infer an absent runtime persistence requirement or remove Redis; inventory installed-version behavior and any live overrides.

Choose a version-supported consistency method for each database/app: a verified quiesced/coordinated capture or application-aware database dumps paired with the matching files/config. An arbitrary live raw database-directory copy is not an application-consistency method. Logical dumps must include required roles/privileges and compatible restoration details; record when the data was captured. Any downtime, maintenance mode, service stop/start or dump procedure needs separate approval and must be tested first. None is executed here.

Archives from eight independently timed guests are not automatically a transactionally consistent platform-wide point. Record the set's time skew and reconcile identity/app changes when choosing a restore generation. Preserve a previous verified generation rather than replace it with an untested one.

## Keys, sensitive material and bootstrap access

Store backups and recovery bundles encrypted with owner-only access, including database dumps and NPM/CA leaf keys. Keep decryption recovery information independently available: an approved external password manager accessible without this platform and/or a securely stored offline recovery copy. Do not keep the only unlock secret, CA key, MFA recovery code or owner password inside Nextcloud, Authentik, tank or the encrypted media that requires it.

Before relying on encryption, demonstrate key/passphrase recovery on a compatible Linux environment. Preserve any encryption-header recovery material required by the chosen format under its vendor-supported procedure, independently protected and tied to the correct media; no header backup or key material is created here. Protect physical recovery copies separately from the disk and document authorized custody.

Host metadata and router exports can also contain secrets. Keep full recovery material outside GitHub; publish only sanitized coverage and real test records. Do not rotate existing credentials as a recovery shortcut or generate replacement CA identity. Treat a recovered secret-bearing test guest as sensitive.

## Safe isolated restore exercise

Every step is deferred until the server, resources and separate approval are available.

1. Select a representative generation from the independent media and prove it can be located, unlocked and read **without tank or the running platform**. Do not disconnect/fail a production pool to simulate this; use a separate workspace and no dependency on its contents.
2. Inventory free CPU/RAM/disk and restore requirements. The historical host has about four cores/15 GB RAM; do not restore/start all guests alongside production by assumption. A large Nextcloud volume may require substantial free allocation. If safe capacity or a separate compatible recovery host is unavailable, defer the full test. Do not shrink/delete production disks to make space.
3. Select a genuinely unused test VMID/storage destination and preserve source archives read-only. Never overwrite an existing VMID or restore into a production path. Obtain explicit approval for restore/storage writes.
4. Restore the clone stopped, with automatic boot disabled. Before first boot, replace **all** restored production NIC/bridge/VLAN/route attachments with a dedicated test network having no physical uplink, production gateway, NAT or permitted forwarding. Inspect all NICs, including additional/IPv6 interfaces. A new MAC/VMID alone is not isolation. Also inspect every restored LXC mp/bind/device mount before first boot: remove production-facing attachments from the clone or remap them to approved dedicated test copies. Never let a test guest write through to production paths, even with all networking disconnected. Do not alter the production guest or source archives to do this.
5. Inspect clone startup behavior offline where possible. Prevent mail, webhooks, scheduled jobs, replication, external mounts, dynamic DNS, backup jobs and identity callbacks from affecting real systems. Do not depend on turning off those services after they already booted. Maintain network isolation even if startup controls fail.
6. Use an isolated test client/console. If DNS/NPM/Authentik are needed, restore a coherent minimal dependency set within that isolated network; resolve intended names only inside the lab and establish test-client trust there. Do not change production/router DNS, real client trust or call live OIDC/SMTP endpoints to make the test pass.
7. Validate data and application behavior: representative PostgreSQL/MariaDB restore checks; Wiki.js pages/roles; Snipe-IT assets/uploads and app-key continuity; Nextcloud file checksums, database/file agreement and access permissions; Authentik permitted/denied logins and signing/secret continuity; NPM TLS/proxy state; DNS and logging where included.
8. Record scope and gaps. One application restore does not prove the whole platform; isolated OIDC validates only the restored test dependency set. Stop on unexpected production connectivity, missing keys, corruption or automatic migration.
9. Shut down test guests and revoke test-network access after evidence is captured. Keep decrypted test data secured until a separately approved cleanup; do not include automatic destructive cleanup commands. Never alter source archives to clean up test state.

The [network plan](NETWORK-SECURITY-PLAN.md) and corrected [firewall reference](../proxmox/firewall-setup.md) are integrated as documentation only; no live restriction or recovery test is applied. Its recovery/deny checks are not already deployed. Isolation must be independently verified even if that proposal is later accepted.

## Host or pool failure checklist

| Situation | Safe recovery path and stop conditions |
|---|---|
| Host/boot disk failed, tank potentially intact | Preserve original disks/identities and evidence. Identify the failure and choose compatible recovery hardware/software. Keep the independent copy intact. Do not run zpool create, format/reinstall over data disks, force import or overwrite host metadata. Plan a separately reviewed import/recovery only after disk/pool inventory; stop on uncertainty. |
| tank unavailable or lost | Recover from the independent verified generation onto approved separate/replacement storage. Local backup-tank is not assumed accessible. If independent media/keys/coverage are missing, state the recovery gap rather than invent a restore path. Preserve failed media; do not initialize it to “repair” the problem. |
| Suspected compromise/destructive incident | Isolate before recovery; select a demonstrably appropriate historical generation and review persistence/credentials. Encryption is not proof an archive is clean. Credential rotation belongs to a separately approved incident plan, after preserving required decryption/key continuity. |

Common rebuild order after approval:

1. Recover owner credentials, media unlock information, CA/trust material, inventory and compatible installer/images independently of the failed platform. Rehearse on isolated recovery resources first.
2. Rebuild host management/bridge/storage mappings only on positively identified approved targets. Reconcile host identity, NIC names, storage IDs and node restrictions; storage.cfg historically restricts tank to node proxmox. Do not bulk overwrite a new host's /etc/pve with an old directory or assume a bare-metal rollback exists.
3. Restore guests stopped into the isolated recovery environment. Preserve every production attachment as inactive until reviewed. Keep automatic guest boot and unintended Docker startup under control.
4. Bring up DNS and logging early in the lab, then NPM and Authentik as a tested dependency set, then applications. Check Docker logging-driver initialization separately; a reachable syslog receiver is not a universal prerequisite for creating containers.
5. Verify data, app-local permissions, allowed/denied identity flows, certificates and consistency. Do not upgrade mutable images or apply historical blueprints during recovery.
6. Plan production cutover separately: ensure only one active identity/IP/MAC instance, reconcile stable addresses/routes/DNS, approve firewall and callback changes, then test from intended clients with console recovery ready.
7. Create and verify fresh local and independent backups after stable recovery through a separately approved operation. Keep the previous verified generation until the replacement is proven. Record actual loss interval and elapsed recovery time.

No executable restore, disk creation, encryption or formatting commands are supplied. Version-matched commands must be prepared against the actual inventory before later approval.

## Verification levels and test record

| Level | What it establishes | What it does not establish |
|---|---|---|
| Job definition/log review | Intended selection/schedule and reported completion | Recoverable data, independent copy or successful restore. |
| Archive/readback manifest | Completeness, size/checksum agreement and readability | Logical app consistency, clean content or working login. |
| Media unlock recovery | Keys/tooling available without platform dependencies | Application recovery. |
| Isolated app restore | Actual tested app/data/login/permission behavior for one generation | Untested apps/generations or guaranteed production cutover. |
| Independent host/pool-loss exercise | Measured recovery of its documented scope without original pool | Hardware already owned, future SLA or immunity from every failure. |

For a future real test, record: test date; source generation/media and capture timestamps; actual versions; recovered VMIDs/services and isolation evidence; files/checksums and DB/app checks; authorized/denied access results; independent key recovery; start/end/elapsed times; latest successfully recovered data time and observed loss interval; issues; scope not tested; follow-up owner/date. Do not populate this with fictional values.

**Current test record: not performed.** The historical restore report remains a historical assertion with missing evidence. No capacity, hardware, encryption, checksum, archive or recovery-time result is claimed by this document.

## Approval gates and rollback

Still required: media ownership/identity/capacity, compatible encryption/recovery tools, independent key custody, destination and retention choice, actual mount/volume coverage, app consistency method, test workspace capacity, unused IDs, verified preboot isolation and scope-specific rollback. Each implementation/backup/restore operation needs separate approval.

Rollback now is documentation-only: discard/revert this proposal. A later failed copy should leave the last verified generation intact; a failed isolated restore should leave source archives and production unchanged. Never treat rollback as permission to erase media, delete guests, overwrite keys or restore over live data. Existing local backups are preserved.
