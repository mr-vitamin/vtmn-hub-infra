# Proxmox Firewall

## Current state (intentionally conservative)

The firewall is **enabled** at the datacenter level but with a **permissive default policy** — it doesn't actually block anything yet. This was a deliberate choice: flipping to a restrictive default carries real risk of locking out remote SSH/web-UI access if a rule is wrong, so that step should be done by a human sitting at the physical console (or with independent out-of-band access confirmed first), not blindly via a remote script.

```bash
pvesh set /cluster/firewall/options --enable 1 --policy_in ACCEPT --policy_out ACCEPT
```

An explicit allow-rule is already staged and ready for when you do tighten the default policy — it stays inert while the default is ACCEPT, but will matter once you flip to DROP:

```bash
pvesh create /cluster/firewall/rules --type in --action ACCEPT \
  --source 192.168.0.0/24 --dest 192.168.0.50 --dport 22,8006 --proto tcp \
  --comment 'Allow LAN to Proxmox SSH and Web UI' --enable 1
```

## To actually enforce (do this deliberately, at the console)

1. Confirm you have console access (not just SSH) in case something goes wrong
2. Verify the LAN allow-rule above is in place and correct for your actual network
3. Flip the default policy:
   ```bash
   pvesh set /cluster/firewall/options --policy_in DROP
   ```
4. Immediately test that SSH and the web UI still work from a LAN client
5. If locked out, use the Proxmox console (keyboard/monitor, or IPMI/iDRAC if available) to run:
   ```bash
   pvesh set /cluster/firewall/options --policy_in ACCEPT
   ```

Current rule set can be inspected with `pvesh get /cluster/firewall/rules` and `pvesh get /cluster/firewall/options`.
