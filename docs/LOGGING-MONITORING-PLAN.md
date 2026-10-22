# Logging, monitoring and owner-alert plan

**Proposal only — October 22, 2026.** Findings LOG-001, LOG-002 and OPS-003 remain open. The server is off. No event was sent, receiver inspected, alert delivered, configuration deployed or service restarted.

## What the repository establishes

| Evidence | Configured behavior | Verification limit |
|---|---|---|
| Six service Compose files | All 13 service definitions select syslog, udp://192.168.0.25:514 and tag {{.Name}}. No explicit syslog-format, TLS or delivery mode/buffer is defined. | Effective overrides, Docker defaults, sender addresses and actual receipt are unknown. |
| [services/syslog/10-remote.conf](../services/syslog/10-remote.conf) | imudp and imtcp listen on port 514. Dynamic path /var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log; global *.* selector followed by stop. | No dedicated remote ruleset/source allowlist/TLS is captured; effective include order and local-log effects are unknown. |
| [setup-syslog.sh](../scripts/setup-syslog.sh) | Duplicates that receiver config; creates /var/log/remote with mode 700. Rotation: daily, rotate 30, compress, delaycompress, missingok, notifempty, copytruncate. | It overwrites fixed config files; it is not a safe reconciliation/inspection command. Runtime service UID, ownership, file modes and scheduler execution are unverified. |
| [LXC definitions](../proxmox/create-containers.sh) | Syslog 107 has rootfs tank:30; guests have onboot enabled. | Allocation is not measured free space, a separate physical failure domain or a readiness sequence. |
| [Homepage widgets](../services/homepage/config/widgets.yaml) | CPU, memory and disk / resources; search. [Service entries](../services/homepage/config/services.yaml) are hostname links. Docker/Proxmox integration files are comment-only in the tracked config. | Resource scope depends on runtime visibility/mounts; no Proxmox pool measurement, active availability checks or notification delivery is established. |
| [Backup definition](../proxmox/backup-job.sh) | Intended daily 02:00 snapshots, all eight LXCs, local backup-tank and retention. | No successful-run age, failure notification, archive integrity or restore is proven. |

Docker logs do not automatically cover every application audit file, host/LXC journal, Proxmox event, reverse-proxy file log or SSH authentication record. Inventory actual event sources before claiming central security visibility.

Centralized logging collects records. Monitoring checks state and trends. Alerting delivers actionable conditions to an owner. Intrusion detection analyzes activity for suspected threats with detection logic. These are different capabilities: this repository's rsyslog/Homepage configuration does not establish a monitored IDS/SIEM or tamper-proof evidence store.

## First improvements: source restriction and receiver routing

Keep current transport while preparing and testing a controlled change; do not silently change every sender or disable logs.

1. Confirm stable syslog 107 identity and actual transport source addresses from each Docker engine in LXCs 101-106, including NAT/IPv6 paths. Restrict receiver inputs to explicitly approved sources through a separately reviewed network rule plan. UDP source restriction reduces unsolicited injection, not cryptographic spoofing.
2. Do not treat a supplied hostname/program/tag as authenticated identity. Record transport source plus parsed message fields and receipt time separately. Validate parser behavior with the selected format; sanitize dynamic path components and map sources to approved directories rather than trusting arbitrary message text as a filesystem path.
3. Plan a dedicated remote-input ruleset explicitly bound to each enabled network input. Put remote-only path/actions and termination inside that ruleset; preserve normal local inputs/default rules. A global catch-all stop can divert local messages depending on includes; present local-log loss is not asserted.
4. Inspect full /etc/rsyslog.conf and include order, installed modules/version, service UID/GID, privilege dropping, directory/file ownership and dynamic creation modes. Root-created mode 700 does not prove a non-root receiver can write. Proposed intent is owner/required-daemon access only, with no ordinary operator write access; choose exact permissions after inventory.
5. Reconcile both the canonical 10-remote.conf and the script's embedded copy when a later change is approved. Preserve originals and relevant rotation/ownership metadata first. Do not rerun the installer over a live receiver.
6. Check the entire version-matched rsyslog configuration in a disposable environment before any restart, then test one local and one remote event. Local records must continue to their intended ordinary destinations, while remote messages take the remote ruleset.

Rsyslog's [multiple-ruleset guidance](https://docs.rsyslog.com/doc/concepts/multi_ruleset.html) supports input-to-ruleset separation; actual syntax/modules remain gated on installed-version checks. No executable candidate receiver config is activated or supplied as universal syntax here.

## Transport, format and outage decision

[Docker's syslog driver](https://docs.docker.com/engine/logging/drivers/syslog/) supports UDP, TCP and TCP/TLS. An explicit supported RFC format, such as rfc5424micro, should be evaluated for timestamps and parsing; none is set now.

- **UDP:** preserves the current minimal setup but provides no delivery acknowledgement, encryption or sender authentication. A successful send is not proof of receipt.
- **TCP:** improves stream transport behavior, but alone provides no confidentiality or authenticated sender identity. A successful socket write/acknowledgement is not proof the receiver durably stored a record.
- **TLS:** a separately approved option when trusted transport is required. Confirm receiver modules and Docker support, server certificate identity/trust and whether client-certificate authentication is supported/enforced end to end. Server-authenticated TLS alone does not establish client identity. Do not use skip-verify.

TLS certificates/keys used by a Docker logging driver must be accessible to the Docker engine in its LXC, not merely inside the application container. A TLS receiver name/IP must resolve to syslog 107 and match the certificate SANs. The current wildcard DNS points at NPM; do not assume a new syslog hostname will reach 107. Do not repurpose a web wildcard as a complete client-identity scheme, copy the CA private key to senders or issue/rotate certificates under this package.

[Docker delivery modes](https://docs.docker.com/engine/logging/configure/#configure-the-delivery-mode-of-log-messages-from-container-to-log-driver) have availability/loss tradeoffs. Blocking can propagate backpressure; non-blocking uses a finite memory buffer that can drop records when full. Neither is an assumed durable sender spool. Receiver action queues cannot recover UDP messages lost before arrival. Document queue limits, restart behavior, drops and saturation response before selecting a mode.

Evaluate logger initialization, receiver outage and restart separately. A reachable UDP receiver is not a universal prerequisite to creating application containers, while a selected driver/transport/configuration can affect startup or log-write behavior. Do not apply a fixed startup sleep or claim TCP/TLS automatically supplies lossless delivery. Existing containers require a separately approved recreation to adopt changed logger options.

For this small system, prioritize verified source restrictions, receipt and disk monitoring first. If evidence requirements make loss unacceptable, assess a version-supported local spooling/relay design separately, with measured limits; do not install another service or promise exactly-once delivery here.

## Rotation, capacity and record protection

The current 30-rotation policy is not a hard 30-day, byte or ingest-rate ceiling. Empty files can skip rotations; large files can grow between runs. The syslog guest's root allocation and tank's shared free space both need checks. Track bytes, inodes, growth rate and projected exhaustion, including compressed/active/temporary files and any future queue.

The upstream [logrotate manual](https://github.com/logrotate/logrotate/blob/main/logrotate.8.in) describes copytruncate's copy/truncate window, where data can be lost. Prefer a tested rename/reopen approach if the actual rsyslog service supports it, with correct ownership and reopen behavior; do not change rotation strategy blindly. Evaluate bounded size-based rotation and an appropriate scheduler frequency together. Neither a size directive nor a daily timer alone guarantees a hard volume cap.

Provisional capacity triggers: warn below 20% free, critical below 10% free or earlier if projected exhaustion is near. Add measured minimum-free-byte and inode thresholds per filesystem before implementation; percentages alone can mislead. Calibrate for the actual 107 rootfs, host boot filesystem, tank and backup path. No capacity or ingest-rate measurement exists now.

Restrict log read/write permissions, preserve time synchronization and source/receipt timestamp distinction, and keep sensitive records/backups encrypted where appropriate. Local owner/root compromise can still alter records. No immutable storage, cryptographic log sealing, guaranteed retention or forensic chain of custody is claimed. Redact secrets/tokens, URL query credentials and personal data before sharing; do not publish raw logs or notification credentials.

On pressure/failure: alert and investigate the source, queue/rotation errors and receiver permissions. Never automatically truncate logs, delete old evidence, stop unrelated production services, fill a filesystem to test alerts or prune backup generations. Follow an owner-reviewed capacity/retention decision and preserve evidence.

## Lightweight checks and owner notifications

The historical host has about four cores and 15 GB RAM. Require a measured CPU/memory/disk budget for all checkers, any relay, aggregate per-container buffers and receiver queues before implementation. Prefer existing Proxmox/OS capabilities plus small bounded checks; no Wazuh, Suricata, Grafana, Prometheus, new monitoring server or extra dashboard integration is deployed. Verify available packages/permissions before selecting any timer/cron implementation. No script or schedule is installed here.

| Check | Proposed signal / cadence | Owner action and limits |
|---|---|---|
| Storage and logs | Free bytes/inodes, tank health, 107 growth/rotation/queue errors; about every 5 minutes where practical | Warn/critical thresholds above after calibration. Treat missing/stale samples as unknown, not healthy. Do not infer host pool health from Homepage disk /. |
| Backup execution | Inspect actual job result/completion age after each run plus a daily stale-success check | Alert failure and missing expected success after a timezone/runtime grace chosen from real duration. A job definition or archive listing is not a usable restore. Check independent-copy age separately once approved. |
| Host health | Existing Proxmox/OS events and available hardware/ZFS status; about every 5 minutes for critical state | Review degraded storage, sustained memory/CPU/disk pressure and required service failures. Do not install agents or assume SMART/ZFS alert delivery is configured. |
| Service availability | Approved internal DNS and HTTPS checks for all five app hostnames; about every 5 minutes with timeout and 2-3 consecutive failures | Distinguish expected SSO redirect/deny from app readiness. Verify TLS name/chain; no skip-verify. Do not use repeated real-user login attempts, weaken auth or expose health paths publicly. |
| Certificate expiry | Daily check of served certificates for all five names plus issuer/root and any future logging credentials | Proposed warning at 30 days, critical at 7 days; also detect validation failure/mismatched host. Do not auto-renew or regenerate the CA. A certificate file alone is not proof NPM serves it. |
| Collector/event freshness | Receiver/rotation status and a small approved synthetic event or expected-source cadence | Quiet real logs do not prove failure. Bound marker frequency and verify actual arrival; never flood or log a secret. |
| Host completely down | Owner-operated check from an independent existing device, if available and approved | An on-host checker cannot notify during complete power/network loss. If no independent observer/channel exists, explicitly retain manual verification and the blind spot. |
| Startup readiness | DB/cache readiness, identity/outpost health and app-level checks when starting/recovering | No Compose healthchecks are specified in source; image-provided checks are unknown. Choose version-supported bounded tests without putting secrets in commands/output. |

[Proxmox notifications](https://github.com/proxmox/pve-docs/blob/master/notifications.adoc) can route supported events through version-dependent matchers/targets. Prefer a verified existing owner destination over installing a new platform. A configured email address is not proof of delivery; direct SMTP targets may lack retry/queue semantics. Check actual job notification settings and supported events, then independently test the chosen channel after separate authorization.

No recipient/channel is selected and no message is sent. Decide where alerts go, how credentials are stored outside Git, who owns response and how the route works during Authentik/NPM/host failure. An alert channel that depends only on this failed platform is insufficient for host-loss detection.

Propose state transitions, deduplication, a bounded reminder while critical, a recovery message, timestamps and a maintenance window. Missing data must not generate a false recovery. Avoid per-event mail storms; retain a small private local status record with bounded size. Confirm test alerts arrive and failures are visible; don't assume automatic retries are universal.

A later low-privilege checker must not require a Homepage Docker-socket mount or a broad Proxmox admin token merely to display status. Native host checks may require protected privileges; keep those separate from user-facing dashboards. Homepage links/widgets remain unchanged and are not an owner notification engine.

## Startup and dependency handling

The source uses short-form depends_on for application/database order, without Compose-defined healthchecks. [Compose startup guidance](https://docs.docker.com/compose/how-tos/startup-order/) distinguishes running from ready. Future readiness checks must be supported by the actual installed image; do not invent a health endpoint or assume a utility exists in every container.

Proposed recovery sequence: host network/storage and time/DNS, early logging setup, DB/cache and identity, NPM/application verification. Cross-LXC onboot settings are not a dependency graph. Inspect existing image checks, retries/restart behavior and logging-driver initialization; then rehearse finite dependency-outage/recovery behavior in isolation. Avoid nested infinite retries, automatic restarts of unrelated services or credential-bearing probes. Ready checks do not replace ongoing monitoring or application acceptance.

## Deferred verification and rollback

All results below are **not tested**. Use a disposable version-matched environment and finite dummy events before any approved live change.

| Scenario | Required evidence |
|---|---|
| Local versus remote routing | One unique local marker reaches its ordinary destination; one marker per approved sender/representative service reaches the intended remote file with correct parsed tag, transport source and timestamps. |
| Attribution / rejection | Verify paths and permissions with safe varied dummy tags; an unapproved sender is rejected. This is a source-control test, not proof UDP cannot be spoofed. |
| Outage / backpressure | Brief bounded collector interruption in the lab; record startup, application/log-write behavior, losses/buffering and post-recovery receipt. Do not claim queue durability without restart/full-buffer tests. |
| Rotation / capacity | Rotate a small isolated fixture; verify pre/post markers and reopen/ownership, scheduler behavior and warning transitions via mocked readings. Never fill production storage or force-rotate live evidence for this test. |
| Alerts | With separate send approval, verify delivery, deduplication, recovery, missing-sample behavior and maintenance suppression through the selected channel. No actual alert was sent for this plan. |
| Dependency and app checks | Simulate one dependency outage in isolation; prove finite retries, correct failure state and controlled recovery without repeated user-login failures or bypass. |
| Host-loss blind spot | Verify the independent observer/route if one exists, otherwise document manual detection and no guaranteed notification during total host outage. |

Before any approved change, privately capture full rsyslog includes, service identity/modes/ownership, rotation config/state, effective logger options and current alert routes. Preserve the known-good files; use version-matched non-mutating config checks before restart. Source rules must be reflected consistently in the setup script and standalone file.

Rollback restores only the approved files/permissions/logger settings through a validated procedure; a file revert does not reconfigure existing Docker containers. Coordinate any recreation to preserve data/availability and retain console recovery. Do not rerun setup scripts, flush firewall rules or delete logs as rollback. Related network, backup, CA and version guidance is integrated locally; no runtime changes are applied. Revalidate the combined candidate and its compatibility/recovery gates before any separately approved rollout.

## Current status and decisions

Installed rsyslog/Docker/Compose/Proxmox versions; service UID and include order; actual sender identities; IPv6/NAT/firewall state; chosen format/transport/loss policy; TLS identity/keys if selected; measured capacity/thresholds; readiness endpoints; alert recipient/channel and independent observer are required decisions. They block safe implementation.

No live delivery, rotation, queue, alert, readiness, monitoring or intrusion-detection result is claimed. Rollback now means discard/revert documentation only. LOG-001, LOG-002 and OPS-003 remain open.
