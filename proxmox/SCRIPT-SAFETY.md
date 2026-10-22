# Proxmox script safety and recovery

These scripts are initial-setup tools, not a complete rebuild or reconciliation system. Source proposals were validated offline on October 22, 2026. The physical server was unavailable; no effective guest, job, storage, DNS or backup state was verified.

## Before any future approved execution

Use a trusted root-owned checkout on the intended Proxmox host, as root, from a local console/recovery-capable session. Inspect the complete proposed diff first. Do not execute these tools simply to inspect existing infrastructure.

Both scripts require Bash, Python 3 (standard library only), pvesh, id, flock and their sibling script-safety.py. Container creation also requires pct, pvesm, ip, GNU timeout (including --kill-after), sleep and a downloaded local Debian 12 template. No dependency is installed automatically. Keep the helper beside both shell scripts. The scripts accept no positional arguments.

The installed Proxmox release is unknown. Confirm its JSON API responses/options against the helper and command lines before any write. Current upstream Backup.pm supports an explicit job ID and returns prune-backups as an object; the helper also accepts the property-string form. Upstream support does not establish installed compatibility:
[Proxmox backup API source](https://github.com/proxmox/pve-manager/blob/master/PVE/API2/Backup.pm).

Preflight checks reject unreadable/malformed guest/job inventories, existing IDs, unsuitable/disabled storage configurations and unavailable prerequisites. They do not prove storage activation, node eligibility, free space, ZFS health, suitable template contents, scheduler timezone, cluster quorum or sufficient host capacity. Check these manually first. This is a single-host architecture; backup jobs select cluster VMIDs without a node restriction.

Each script takes a nonblocking advisory flock on its own script inode. This only coordinates invocations of the same file on the same host. Independent copies, UI operations and other hosts are outside that lock. Do not run competing provisioning/schedule changes. API VMID uniqueness and the fixed backup-job ID add protection; this is not a cluster-wide transaction or a guarantee against independent jobs with different IDs.

## Container creation

The eight original guest definitions are preserved: 108 DNS first; 101 Wiki.js; 102 Snipe-IT; 103 Homepage; 104 Authentik; 105 NPM; 106 Nextcloud; 107 syslog. CPU, memory, swap, disks, vmbr0/DHCP, unprivileged settings, onboot and nesting/keyctl choices are unchanged. Only 108 is started. No service, nameserver change or guest reboot is automatically applied.

Before any guest is created, the cluster-wide VM inventory must show all VMIDs 101-108 unused by either QEMU or LXC. A failed query is never treated as absence. Existing IDs cause refusal, including a partially completed previous run.

TEMPLATE may override the default local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst. It must be a local:vztmpl archive filename ending in .tar.zst, .tar.xz or .tar.gz, without path components. pvesm must resolve it to a readable regular file. This check does not validate the archive's contents or OS.

After starting 108, poll eth0 for exactly one usable global-scope IPv4 address. A private LAN IPv4 is acceptable; loopback, link-local, multicast, unspecified and broadcast are rejected. Defaults: DNS_ATTEMPTS=30, DNS_INTERVAL=2 seconds; accepted ranges are 1-60 and 1-10 respectively, without leading zeros. Each pct exec attempt has a 10-second timeout and 2-second kill grace. The loop retries reads only, with at most attempts-minus-one sleeps. Host scheduling and helper execution can add time; this is not a total wall-clock SLA.

An assigned address does not prove DNS works. Configure dnsmasq separately using the reviewed DNS setup procedure, verify intended names from a client, then type DNS-READY. Empty input, EOF or another response stops before creating 101-107. The script itself makes no DNS queries or network probes.

The original DHCP architecture remains, including the unresolved stable-address issue. Do not assume this address matches committed hard-coded integrations or remains stable after restart. Record/reserve addresses and reconcile dependencies through the separate network plan before service setup. Docker is intended for 101-106; configure rsyslog directly in 107.

## Backup scheduling

Preserved policy: daily 02:00 (scheduler timezone), explicit IDs 101-108, backup-tank, snapshot, zstd, enabled, retention keep-daily=7 and keep-weekly=4. Snapshot mode is not a guarantee of zero disruption or application-consistent databases. Storage remains on the documented shared pool; independent disaster recovery is not solved here.

The inventory must contain all eight IDs as LXC guests, and backup-tank must support backup content and not be disabled. No immediate backup is launched.

- One equivalent existing job, including a legacy/generated ID: exit successfully with an explicit no-change message.
- Multiple overlapping jobs, a disabled/differently configured job, an all-guests/pool/ambiguous selection, or an occupied vtmn-hub-daily ID: refuse for manual review.
- Equivalence is deliberately conservative: schedule text must be exactly 02:00, selection must be the same eight IDs, and the policy/retention must match. Extra execution/scope options prevent automatic adoption. Different but mathematically equivalent calendar expressions can require manual review.
- Disjoint explicit VMID jobs can coexist. Overlap is refused even at a different time/storage; legitimate additional policies need an intentional manual decision.
- No relevant existing policy: create vtmn-hub-daily once, then read the full job list again and confirm a unique matching definition before reporting creation success.

There is no automatic update, enable, delete or create retry. A fixed ID prevents simultaneous copies from creating multiple jobs under that ID on compatible Proxmox versions. An external actor can still create a different overlapping ID between read and write; readback detects a visible conflict but does not undo the write or stop the scheduler.

A successfully registered job proves neither backup execution nor recoverability.

## Partial failure and safe recovery

Failures return nonzero, identify the stage, list attempted writes (including a possibly failed/partially completed command), and retain state. A command failure may still leave a guest/job behind. Do not assume attempted means successfully created, or that an error means nothing changed.

1. Stop; preserve console output and inspect cluster/host guest and backup-job inventories using separately reviewed read-only commands or UI.
2. Determine exactly which IDs, configurations, disks and scheduled jobs exist. Inspect failed attempts too. Do not rerun to discover this.
3. For container failures, compare each guest and disk with the intended definition. Existing IDs intentionally block rerunning the initializer. Resume only through a separately reviewed manual plan; do not delete guests/disks merely to make this script pass.
4. If backup creation or readback failed, inspect the job list before retrying. A schedule may already be active even though success was not printed. Review any duplicate/overlapping or mismatched policy manually. This tool never disables or deletes it.
5. After approval, reconcile only the identified partial state. Do not run automatic cleanup, bulk guest deletion, restore over existing IDs or create a new job ID to bypass the guard.

For any future restore test, use a throwaway unused ID and an isolated network before first boot. A new MAC alone does not prevent duplicate static IPs, hostnames, DNS records, cron jobs, outbound mail, SSO or application side effects. Detailed independent-backup and isolated-restore planning belongs to Work Package 8.

## Offline verification and deferred checks

tests/test-proxmox-safety.py executes these scripts against disposable command substitutes and a Python JSON helper. It must never be pointed at a real command wrapper or used as a deployment test. Set WP_SOURCE to the candidate tree, WP_TEST_WORK to a dedicated local fixture directory and optionally WP_BASH to the Bash executable; run with Python 3. No third-party Python package is required. Fixtures are retained for inspection. On Windows the harness normalizes shell paths, forces stub lookup and prevents MSYS conversion of API paths.

Before any future approved use, still verify on a disposable Linux/Proxmox environment: actual flock/FD semantics, GNU timeout behavior, installed API/JSON schema, template/storage/node suitability, create/start task completion and failure reporting, DHCP timing, DNS resolution, resource limits, scheduler policy/timezone and backup/isolated restore. The offline suite does not establish those runtime properties.

## Rollback

Nothing was deployed by this proposal. Reject/discard the local proposed diff if unwanted. If later applied to source, revert only the approved package's source changes while preserving unrelated work. Reverting files does not undo guest creation, disks or active jobs; review actual state and use a separately approved recovery action. Keep existing backup data and CA/credential material intact.


## Offline test interpreter

The bundled test harness requires Python 3.10 or newer (Path.write_text newline support); runtime helper code uses the Python 3 standard library. Match the actual host interpreter/API before execution. Windows mock checks do not prove Linux permissions, locking, process termination or Proxmox API compatibility.
