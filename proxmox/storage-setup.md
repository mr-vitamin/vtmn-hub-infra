# Storage Setup

**Historical configuration reference.** Reviewed October 22, 2026 with the server off; actual disks, pool health and storage mappings are unverified. Disk initialization and storage-registration examples below are state-changing, not recovery/rerun instructions. Do not run them against existing data or unverified disk identities. See the [backup and disaster-recovery plan](../docs/BACKUP-RECOVERY-PLAN.md) before planning host/pool recovery.

## `tank` — main ZFS pool

A mirror of 2× 6TB drives, used for all container root disks:

```bash
zpool create tank mirror /dev/disk/by-id/<disk1-id> /dev/disk/by-id/<disk2-id>
```

Register it with Proxmox:

```bash
pvesm add zfspool tank --pool tank --content rootdir,images
```

Check `zpool status tank` afterward to confirm it shows `mirror-0` with both disks `ONLINE`.

## `backup-tank` — backup storage on the same pool

A plain directory storage pointed at a folder on `tank`, separate from the LVM boot disk but on the **same pool as service data**. This is a useful local archive destination, not an independent backup. A mirror does not protect these archives from complete pool loss, host-level destructive access or a shared disaster. Preserve current local backups; an independent encrypted copy is proposed in the recovery plan, not implemented here:

```bash
mkdir -p /tank/backups
pvesm add dir backup-tank --path /tank/backups --content backup
```

## Full `/etc/pve/storage.cfg` reference (historical configuration)

```
dir: local
	path /var/lib/vz
	content vztmpl,backup,iso,import

lvmthin: local-lvm
	thinpool data
	vgname pve
	content images,rootdir

zfspool: tank
	pool tank
	content rootdir,images
	mountpoint /tank
	nodes proxmox

dir: backup-tank
	path /tank/backups
	content backup
```

`local` and `local-lvm` are the default boot-disk storages created by the Proxmox installer — not touched by this project, but no service container root disks live there (all moved to `tank` for redundancy).
