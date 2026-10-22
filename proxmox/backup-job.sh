#!/bin/bash
# Create the documented schedule once; never update/delete jobs or run a backup.
set -euo pipefail
stage="checking prerequisites"
attempted="none"
trap 'rc=$?; if (( rc != 0 )); then
  printf "FAILED during %s (exit %s). Attempted writes: %s.\n" "$stage" "$rc" "$attempted" >&2
  printf "Do not retry blindly. Inspect actual guests/jobs, including failed attempts. No automatic cleanup was performed. See proxmox/SCRIPT-SAFETY.md.\n" >&2
fi' EXIT
die() { printf '%s\n' "$*" >&2; exit 1; }
[[ $# == 0 ]] || die "No positional arguments supported; see proxmox/SCRIPT-SAFETY.md."
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CHECK="$SCRIPT_DIR/script-safety.py"
for tool in python3 pvesh flock id; do
  command -v "$tool" >/dev/null || die "Required command missing: $tool"
done
[[ $(id -u) == 0 ]] || die "Run on the intended Proxmox host as root."
[[ -r "$CHECK" ]] || die "Required sibling file missing/unreadable: $CHECK"
# Advisory lock on this script inode; does not coordinate copies or other tools.
exec 9<"${BASH_SOURCE[0]}"
flock -n 9 || die "Another invocation of this script holds its lock."

stage="checking target guests and backup storage"
pvesh get /cluster/resources --type vm --output-format json | python3 "$CHECK" backup-guests
pvesh get /storage/backup-tank --output-format json | python3 "$CHECK" backup-storage
stage="checking existing backup policies"
decision=$(pvesh get /cluster/backup --output-format json | python3 "$CHECK" jobs)
if [[ $decision == exists ]]; then
  printf 'An equivalent backup job already exists; no changes made. No backup or restore was tested.\n'
  exit 0
fi
[[ $decision == create ]] || die "Unexpected backup decision; nothing changed."
stage="creating job vtmn-hub-daily"
attempted="create backup job vtmn-hub-daily"
pvesh create /cluster/backup \
  --id vtmn-hub-daily \
  --schedule '02:00' \
  --all 0 \
  --vmid '101,102,103,104,105,106,107,108' \
  --storage backup-tank \
  --mode snapshot \
  --compress zstd \
  --enabled 1 \
  --prune-backups 'keep-daily=7,keep-weekly=4'
stage="verifying the newly created job definition"
pvesh get /cluster/backup --output-format json | python3 "$CHECK" verify-job >/dev/null
stage="complete"
printf 'Backup job created and its definition read back. No backup was run or verified.\n'
printf 'Schedule: daily 02:00 in the Proxmox scheduler timezone; snapshot, zstd, backup-tank, 7 daily + 4 weekly.\n'
printf 'Snapshot mode does not guarantee zero disruption or application-consistent databases.\n'
printf 'A restore test remains required. Isolate restored guests before starting them; a fresh MAC alone does not prevent application or network conflicts.\n'
printf 'See proxmox/SCRIPT-SAFETY.md for prerequisites, partial failure and recovery.\n'
