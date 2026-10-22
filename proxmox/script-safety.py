#!/usr/bin/env python3
"""Fail-closed JSON checks for the Proxmox scripts; Python standard library only."""
import ipaddress
import json
import re
import sys
IDS = set(range(101, 109))
JOB_ID = "vtmn-hub-daily"

def require(condition, message):
    if not condition:
        raise ValueError(message)

def objects(value):
    require(isinstance(value, list) and all(isinstance(x, dict) for x in value),
            "Expected a JSON array of objects")
    return value

def vmids(value):
    require(isinstance(value, (str, int)) and not isinstance(value, bool), "Invalid VMID selection")
    parts = re.split(r"[\s,;]+", str(value).strip())
    require(parts and all(re.fullmatch(r"[1-9][0-9]*", p) for p in parts), "Invalid VMID selection")
    return {int(p) for p in parts}

def flag(value):
    require(value in (0, 1, "0", "1", False, True), "Invalid boolean option")
    return int(value)

def equivalent(job):
    allowed = {"id", "type", "comment", "next-run", "schedule", "all", "vmid", "storage",
               "mode", "compress", "enabled", "prune-backups"}
    if set(job) - allowed:
        return False
    retention = job.get("prune-backups")
    if isinstance(retention, str):
        pairs = [p.split("=", 1) for p in retention.split(",")]
        if any(len(p) != 2 for p in pairs) or len({p[0] for p in pairs}) != len(pairs):
            return False
        retention = dict(pairs)
    return (flag(job.get("all", 0)) == 0 and vmids(job.get("vmid", "")) == IDS
            and job.get("schedule") == "02:00" and job.get("storage") == "backup-tank"
            and job.get("mode") == "snapshot" and job.get("compress") == "zstd"
            and flag(job.get("enabled", 1)) == 1
            and isinstance(retention, dict) and set(retention) == {"keep-daily", "keep-weekly"}
            and str(retention["keep-daily"]) == "7" and str(retention["keep-weekly"]) == "4")

def jobs(value, verify=False):
    relevant = []
    for job in objects(value):
        require(isinstance(job.get("id"), str) and bool(job["id"]), "Job without a valid ID")
        all_guests = flag(job.get("all", 0))
        selected = vmids(job["vmid"]) if job.get("vmid") else set()
        ambiguous = bool(job.get("pool")) or (not selected and not all_guests)
        if all_guests or ambiguous or selected & IDS or job["id"] == JOB_ID:
            relevant.append(job)
    if verify:
        require(len(relevant) == 1 and relevant[0]["id"] == JOB_ID and equivalent(relevant[0]),
                "Created job could not be uniquely verified; inspect jobs before any retry")
        print("verified")
    elif not relevant:
        print("create")
    else:
        require(len(relevant) == 1 and equivalent(relevant[0]),
                "Existing overlapping, conflicting or ambiguous jobs; review manually, no changes made")
        print("exists")

def main():
    require(len(sys.argv) == 2, "Expected one validation mode")
    mode = sys.argv[1]
    data = json.load(sys.stdin)
    if mode in ("new-guests", "backup-guests"):
        found = {}
        for item in objects(data):
            require(isinstance(item.get("vmid"), int) and item.get("type") in ("qemu", "lxc"),
                    "Malformed guest inventory")
            require(item["vmid"] not in found, "Duplicate VMID in inventory")
            found[item["vmid"]] = item["type"]
        if mode == "new-guests":
            require(not IDS.intersection(found), "One or more VMIDs 101-108 already exist; nothing created")
        else:
            require(all(found.get(i) == "lxc" for i in IDS), "Expected all eight LXC IDs 101-108")
    elif mode in ("root-storage", "backup-storage"):
        require(isinstance(data, dict), "Expected a storage configuration object")
        require(flag(data.get("disable", 0)) == 0, "Storage is disabled")
        content = data.get("content")
        require(isinstance(content, str), "Storage content list missing")
        required = "rootdir" if mode == "root-storage" else "backup"
        require(required in content.split(","), "Storage does not support " + required)
        if mode == "root-storage":
            require(data.get("type") == "zfspool", "tank must be ZFS storage")
    elif mode == "dns-address":
        addresses = []
        for interface in objects(data):
            require(isinstance(interface.get("addr_info"), list), "Missing address information")
            for addr in interface["addr_info"]:
                require(isinstance(addr, dict), "Malformed address information")
                if addr.get("family") == "inet" and addr.get("scope") == "global":
                    ip = ipaddress.IPv4Address(addr["local"])
                    require(not (ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_unspecified
                                 or str(ip) == "255.255.255.255"), "Unusable DNS address")
                    addresses.append(str(ip))
        require(len(set(addresses)) == 1, "Expected exactly one global-scope IPv4 address on eth0")
        print(addresses[0])
    elif mode in ("jobs", "verify-job"):
        jobs(data, mode == "verify-job")
    else:
        raise ValueError("Unknown validation mode")

if __name__ == "__main__":
    try:
        main()
    except (ValueError, TypeError, KeyError, OSError) as exc:
        print("Safety check failed: " + str(exc), file=sys.stderr)
        sys.exit(1)
