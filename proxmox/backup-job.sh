#!/bin/bash
# Recreates the scheduled daily backup job. Run on the Proxmox host as root.
# Current config: daily at 02:00, all 8 containers, snapshot mode (no downtime),
# zstd compression, stored on the redundant backup-tank storage.
# Retention: 7 daily + 4 weekly restore points.

pvesh create /cluster/backup \
  --schedule '02:00' \
  --all 0 \
  --vmid '101,102,103,104,105,106,107,108' \
  --storage backup-tank \
  --mode snapshot \
  --compress zstd \
  --enabled 1 \
  --prune-backups 'keep-daily=7,keep-weekly=4'

echo "Backup job created. Verify with: pvesh get /cluster/backup"
echo ""
echo "To run an immediate backup of all containers (e.g. right after setup):"
echo "  vzdump 101 102 103 104 105 106 107 108 --storage backup-tank --mode snapshot --compress zstd"
echo ""
echo "IMPORTANT: a backup that has never been restored should not be trusted."
echo "Periodically test-restore one container to a throwaway VMID to confirm"
echo "backups are actually usable, not just 'reporting success'. When doing so,"
echo "give the restored container a fresh MAC address (--net0 ...,hwaddr=<new>)"
echo "before starting it, or it will conflict with the live container's IP/MAC."
