# Proxmox firewall — historical record and planning boundary

**Reviewed October 22, 2026. The server is off. No firewall setting was inspected live or changed.**

Use the [network security plan](../docs/NETWORK-SECURITY-PLAN.md) for the proposed access matrix, stable addressing, IPv4/IPv6 coverage, staged testing and console recovery. It is a proposal, not executable policy.

## What the repository previously recorded

The historical guide described datacenter firewall enablement with policy_in=ACCEPT and policy_out=ACCEPT. It also included an enabled TCP allow from 192.168.0.0/24 to host 192.168.0.50 ports 22 and 8006.

These were recorded intentions/commands, not a current exported effective ruleset. An enabled ACCEPT rule is not inherently inactive when the default is ACCEPT; actual effects depend on order, exceptions and the remaining rules. The source does not prove that nothing is blocked, nor that every LAN device is an authorized administrator.

The provisioning definitions bridge DHCP LXCs through vmbr0 and omit a per-NIC firewall=1 flag. Runtime flags, guest/node rules, installed backend and Docker forwarding paths remain unverified. Datacenter policy alone cannot establish an application-backend boundary.

## Why the old enforcement shortcut is not a procedure

Changing the datacenter inbound default to DROP after checking a whole-LAN allow is not a complete plan. It can leave backend ports reachable, retain overbroad management access or interrupt services/recovery, depending on the effective rules and topology.

The previous policy_in=ACCEPT console hint was not universal recovery: it cannot undo guest-specific rules, NIC/source filters, Docker paths or router/address changes. Restore the exact captured state at the changed scope through a version-matched procedure.

The former state-changing command examples are intentionally removed from this operational entry point so they cannot be mistaken for an approved rollout. Their original bytes remain available in repository history. No current configuration export is replaced.

## Before any later enforcement

- Obtain separate implementation approval and independent physical/out-of-band console access; do not assume hardware management exists.
- Inventory actual versions/backends, rules/options/default exceptions at every scope, NIC flags, addresses, Docker publications and IPv6 paths.
- Define exact owner sources and stable service identities; preserve DNS/DHCP/required control traffic before restrictions.
- Prepare and validate a private known-good snapshot plus scope-specific recovery instructions.
- Test one guest boundary: NPM success, ordinary-client backend denial, owner recovery, both IP families, authentication and logging.
- Expand only after each result is reviewed. A new default-deny policy is a separate decision, not authorized by this document.

Do not apply rules, change service bindings, disable IPv6, flush rules, switch firewall engines or restrict management automatically. No controls are implemented here. Follow the [plan's acceptance and recovery requirements](../docs/NETWORK-SECURITY-PLAN.md#acceptance-checklist-and-evidence) before future work.
