# Network security and stable addressing plan

**Proposal only — October 22, 2026.** Findings: SEC-001, NET-001, SEC-003. The physical server is off. No address, rule, listener, policy or router setting has been changed or tested. Historical values below are evidence from the repository, not a live inventory.

## Evidence and intended boundary

The [infrastructure reference](INFRASTRUCTURE.md) describes one Proxmox host on vmbr0, one LAN, eight LXCs and an internal-only application domain. [Provisioning](../proxmox/create-containers.sh) specifies DHCP for every LXC. The [firewall record](../proxmox/firewall-setup.md) describes permissive policies and a whole-LAN management allow; it does not establish effective guest isolation.

Six Compose stacks publish application/management ports without a host-IP restriction. NPM is in a separate LXC, so it must reach application LXCs over the LAN. Databases/Redis have no committed LAN port publications. The [NPM reference](../services/npm/README.md) and three exports distinguish app backends from Authentik's outpost endpoint. Missing auth/drive exports and conflicting historical identity settings must be reconciled before deployment.

Target: ordinary users reach application hostnames through NPM and retain application-level authorization; they cannot directly reach backend app ports. Owners use a separately trusted administrative path. Service-to-service flows are explicit. This is an access-control proposal, not proof of resistance to a compromised NPM host or a malicious device impersonating an allowed IP on the same LAN.

## Address inventory and proposed stable strategy

Prefer DHCP reservations to preserve the existing DHCP provisioning and avoid unnecessary renumbering. **These are candidate reservations, not assignments.** First verify router capability, current leases, excluded/reserved ranges, all relevant interfaces/MACs, subnet/gateway and absence of duplicate/static devices. A reservation authenticates neither a device nor a user.

| Role | VMID | Historical IPv4 / candidate to retain | Address authority to establish |
|---|---|---|---|
| Router / upstream resolver | — | 192.168.0.1 | Confirm actual router/subnet/DHCP server and settings. |
| Proxmox host | — | 192.168.0.50/24 | Document existing static configuration; prevent DHCP allocation of this address. |
| Wiki.js | 101 | 192.168.0.176 | Verified reservation tied to actual LXC NIC identity. |
| Snipe-IT | 102 | 192.168.0.175 | Same gate. |
| Homepage | 103 | 192.168.0.56 | Same gate. |
| Authentik | 104 | 192.168.0.124 | Same gate. |
| NPM | 105 | 192.168.0.31 | Same gate; current wildcard DNS target. |
| Nextcloud | 106 | 192.168.0.231 | Same gate. |
| Syslog | 107 | 192.168.0.25 | Same gate; current Docker log target. |
| DNS | 108 | 192.168.0.194 | Same gate; verify actual client resolver distribution. |
| Owner administration / recovery clients | — | **Unknown — do not fill from the whole LAN** | Record exact approved IPv4/IPv6 sources and reserve them or use an approved management path. |
| Ordinary application clients | — | **Unknown** | Define actual trusted client ranges separately from owners; do not assume every LAN device is trusted. |
| DHCP server, time server, external dependencies | — | DHCP/time identities not established | Inventory; do not infer every service is the router. DNS upstreams are documented separately below. |

Maintain a private authoritative inventory of VMID, role, NIC/MAC, reserved address, prefix, gateway, DNS and owner, with sanitized repository documentation. New or restored guests can have different MACs; never activate conflicting reservations or boot a restored duplicate onto production. Router configuration is not present in this repository.

If reservations cannot be supported, obtain approval for a conflict-free static range outside dynamic allocation, then prepare a separate per-guest change with console access. Do not guess a free range or switch both reservation/static methods inconsistently. Static addressing is a fallback decision, not implemented here.

After a future approved assignment, verify DNS/NPM/syslog first, then reconcile every dependent value: dnsmasq and setup-dns.sh NPM targets; LXC/client resolver settings; all six Compose syslog targets; NPM app/outpost destinations; Authentik provider/internal/external URLs; Homepage allowed hosts and dashboard links; Snipe-IT URL; Nextcloud trusted domains/proxies and callbacks. Same-domain HTTPS identities should remain stable. Renew/reboot one disposable/test guest and compare the new lease with the plan before relying on it. This package does not parameterize or rewrite those files.

## Proposed access matrix

All entries are desired policy, not installed rules. Source roles require verified address sets. Ports refer to destination LXC/host publications unless stated otherwise. Allow established return traffic only for permitted flows; it is not a general reverse-direction allow.

| ID | Source | Destination | Protocol / destination port | Intended decision and condition |
|---|---|---|---|---|
| M01 | Approved owner management sources | Proxmox 192.168.0.50 | TCP 8006; TCP 22 if SSH is needed | Allow verified HTTPS UI / approved SSH. Restrict inherited broad management exceptions as part of later reviewed enforcement. |
| M02 | Ordinary users / other guests | Proxmox management | TCP 8006, 22 and other discovered management listeners | Deny. No whole-LAN owner equivalence. |
| M03 | Approved application clients, including owner | NPM 105 | TCP 443 | Allow client HTTPS for auth, hub, docs, inventory and drive; trusted CA and app/identity policies still required. |
| M04 | Same application clients | NPM 105 | TCP 80 | Allow only if required for intentional HTTPS redirects; never submit credentials or serve authenticated content over HTTP. |
| M05 | Approved owner management path | NPM administration 105 | TCP 81 | Allow only with separately verified transport protection/recovery. No committed HTTPS listener on 81 is proven. |
| M06 | Ordinary users / unauthorized sources | NPM administration | TCP 81 and any discovered alternate admin endpoint | Deny, including IPv6. Application-host access is not admin access. |
| M07 | NPM 105 only | Wiki.js 101 | TCP 3002 → container 3000 | Allow app backend; NPM enforces forward-auth, Wiki.js retains local authorization. |
| M08 | NPM 105 only | Snipe-IT 102 | TCP 8083 → container 80 | Allow app backend; retain local authentication/permissions. |
| M09 | NPM 105 only | Homepage 103 | TCP 3001 → container 3000 | Allow backend only through intended proxy gate. |
| M10 | NPM 105 only | Authentik 104 | TCP 9000 → container 9000 | Allow login/provider and embedded outpost traffic. Authentik's own authentication remains authoritative. |
| M11 | NPM 105 only | Nextcloud 106 | TCP 8443 → container 80 | Allow HTTP upstream for documented native OIDC route; 8443 does not mean backend TLS. Retain Nextcloud authorization. |
| M12 | Ordinary clients and other non-NPM LAN sources | All backends above | TCP 3002, 8083, 3001, 9000, 8443 at their respective guests | Deny direct access on every reachable address/interface. No routine owner exception to application backend ports. |
| M13 | Nextcloud 106; Authentik server/worker only if inventory confirms need | NPM auth hostname | TCP 443 | Allow required OIDC discovery/token/user-info or external-URL calls through auth.vtmn.internal; validate DNS, CA trust and NPM hairpin routing. Not a blanket inter-guest allow. |
| M14 | Owner / approved app clients and host/LXCs that need DNS | DNS 108 | UDP/TCP 53 | Allow from explicit trusted source sets; TCP supports large replies/fallback. Do not expose a general public resolver. |
| M15 | DNS 108 | Documented upstream resolvers 192.168.0.1 and 1.1.1.1 | UDP/TCP 53 | Preserve configured forwarding after confirming router resolver identity. Public fallback does not resolve private names for clients if internal DNS is bypassed. |
| M16 | Docker engines in LXCs 101-106 | Syslog 107 | UDP 514 | Allow current Compose logging. Verify actual source addresses after Docker networking/NAT; don't trust a log tag as identity. |
| M17 | Other LAN devices / ordinary users | Syslog receiver | UDP/TCP 514 | Deny ingestion from unauthorized sources. TCP listener exists in source, but no committed sender uses it; allow only separately approved future senders. |
| M18 | Approved owner path | LXCs for maintenance | TCP 22 only where SSH is actually installed/required; otherwise local Proxmox console | No assumed SSH listener and no universal guest-management exception. Console transport must be covered before host filtering. |
| M19 | Each app component | Its own private Docker database/Redis dependencies | Internal Docker network; actual service ports to inventory | Preserve required same-stack connectivity. No LAN database/cache publication or cross-stack access is proposed. |
| M20 | DHCP clients / verified DHCP server | DHCP infrastructure | IPv4 UDP client 68 / server 67, including bootstrap broadcast | Preserve lease acquisition/renewal before source/IP restrictions; exact DHCP server is unverified. DHCPv6 546/547 only if used. |
| M21 | Host/LXCs | Approved maintenance/time destinations | Updates/registries generally TCP 443 and any verified HTTP repository requirements; time typically UDP 123 | Inventory first. Do not apply blanket outbound deny or guess a working egress allowlist. Scope maintenance access separately. |
| M22 | Relevant peers / verified network infrastructure | Interfaces carrying permitted traffic | ARP for IPv4; required ICMP/ICMPv6, including path-MTU/error and IPv6 discovery/control | Preserve essential network operation with backend-appropriate controls; do not blanket-block ICMPv6. |
| M23 | Internet / untrusted networks | Host and service ports | All unsolicited inbound | No new WAN forwarding, public DNS or public exposure. Verify actual router forwarding/UPnP state later; internal naming alone proves no isolation. |

Rows M07-M12 express allowed initiators, not an instruction to bind apps to loopback. NPM lives in another LXC and would lose access. Same-LAN traffic may never traverse the router, so router-only rules cannot establish this boundary. Check direct routes to Docker networks/containers as well as published LXC ports.

Owner-only access is source/path restriction plus service authentication. Authentik administration shares its application listener and requires actual app permissions/policies; firewall ports cannot separate admin URLs from login endpoints by themselves.

## Enforcement design — later, separately approved

Prefer guest-interface/bridge filtering on the existing Proxmox topology after validating its actual packet path, instead of adding a new appliance or platform. A guest-side firewall is supplementary only if it actually covers Docker's published/forwarded traffic. A host INPUT rule is not evidence that bridged LXC traffic is filtered.

Inventory the installed Proxmox firewall service/backend, datacenter/node/guest options, NIC flags, rule order, aliases, automatic/default exceptions, IPv4/IPv6 paths and Docker NAT/forwarding behavior. Provisioning omits per-NIC firewall=1; no current effective flag is inferred. Do not migrate firewall engines merely to implement this plan.

Docker documents that [published ports](https://docs.docker.com/engine/network/port-publishing/) can expose host/container address paths, while [packet filtering](https://docs.docker.com/engine/network/packet-filtering-firewalls/) must account for Docker-managed rules. A generic guest INPUT/ufw rule may not cover those paths. Do not flush Docker chains or disable its firewall management as a shortcut.

[Proxmox's firewall reference](https://github.com/proxmox/pve-docs/blob/master/pve-firewall.adoc) distinguishes host and guest controls, NIC enablement and backend-dependent features. Translate the matrix into rules only after installed-version and disposable-path checks. Do not assume a datacenter default policy implements guest isolation, or that a future backend's rule syntax works on the installed engine.

Future sequence, after separate implementation approval:

1. Confirm physical/independent console login and exact-state rollback. Resolve owner sources, address authority, DNS and DHCP/IPv6 essentials first. Stop if any are unknown.
2. Secure the owner management path and verify a new session. Inventory broad whole-LAN/default management exceptions before planning their removal; preserving an existing session is insufficient.
3. Validate one test guest/backend boundary with NPM-to-app success and ordinary-client denial, including direct Docker addressing and both IP families. If installed controls cannot enforce it, stop and revise the design.
4. Prepare specific service allow/deny changes for one guest at a time. Preserve approved DNS, DHCP, logging, app dependencies, return traffic and maintenance paths. Test and review before each expansion.
5. Only after full coverage is demonstrated consider a separate policy-default proposal. **This plan does not authorize changing any default to DROP/default-deny.** No whole-LAN allow should silently replace the explicit service matrix.
6. Test again after a controlled guest/network restart in a disposable or approved maintenance environment. Capture actual evidence; rollback on any failed acceptance condition.

Because the LAN has no documented management VLAN or switch anti-spoofing, allowed source addresses can potentially be impersonated. Validate available Proxmox source/MAC filtering without breaking DHCP or restored guests; reservations alone are not anti-spoofing. If hostile same-LAN devices are a realistic requirement, separately assess supported switch/router segmentation. No VLAN, new subnet, port security or extra hardware capability is assumed here.

## IPv4, IPv6 and transport decisions

Inventory all guest/host IPv4 aliases, IPv6 global/ULA/link-local addresses, router advertisements, DHCPv6, Docker listeners/proxy settings and any AAAA records. Do not equate an IPv4-only DNS record with an IPv6 access restriction: a literal IPv6 address can bypass DNS.

If IPv6 is used, represent approved owners/services in stable IPv6 sets and enforce/test equivalent decisions, including link-local paths on the same segment. Preserve necessary neighbor discovery, duplicate-address detection, path MTU and trusted-router control traffic; distinguish essential protocol traffic from arbitrary inbound access. If IPv6 is not intended, choose a separately reviewed disable/restrict approach at all relevant layers with console recovery; nothing is disabled by this proposal. IPv4 restrictions alone cannot meet acceptance.

SEC-003 also requires transport decisions. Client application access should use validated HTTPS through NPM. NPM port 81 must not be assumed HTTPS: prefer an approved verified TLS management endpoint or encrypted tunnel ending within NPM's LXC, with any plaintext hop confined to that protected endpoint. A tunnel ending on Proxmox and then crossing the LAN in HTTP does not protect the final hop. SSH/tunnel availability and management hostname/certificate choices are unverified; until a protected path is established, use console recovery rather than send credentials over unverified HTTP.

The documented NPM-to-app/outpost links use HTTP. Restricting sources does not encrypt them. Explicitly record any temporary acceptance of LAN interception risk; prioritize validated upstream TLS for identity/admin traffic crossing a less-trusted boundary through a separate compatibility/certificate change. Do not replace http with https blindly or disable certificate verification to make it work.

Retire historical HTTP OIDC callback alternatives only after canonical HTTPS Nextcloud login and recovery are proven, in the application/identity work package. Do not remove callbacks, rotate credentials or change application permissions in this network plan.

## Administrative recovery procedure

No runnable firewall commands are supplied because the effective backend and prior state are unknown.

Before enforcement, save a secure private snapshot of actual datacenter/node/guest firewall definitions and enable/default settings, NIC flags, generated/effective rules, Docker networks/port maps, guest network config and router reservations. Record versions, exact intended changes and the backend-specific validated restore procedure. Validate its syntax/availability in a disposable setting and keep an offline copy at the console. Backups alone are not a rehearsed recovery method.

Have local keyboard/monitor or independently verified out-of-band access and authorized host credentials. Do not assume IPMI/iDRAC exists. Keep the current admin session while also testing a fresh one. If available, independently validate a bounded rollback mechanism; do not invent a generic timer command or rely on it as the only recovery path.

If access or services fail during future approved work:

1. Stop further changes. Use the independent console; do not reboot or rerun provisioning as a first response.
2. Identify the last changed scope: router/address, node/guest rule, NIC flag or Docker path. Inspect locally; avoid repeated blind remote changes.
3. Restore the exact previously recorded objects/settings for that scope with the version-matched procedure. Do not flush all firewall/Docker rules or overwrite unrelated cluster configuration.
4. Verify local interfaces/leases/routes, then a fresh owner UI/SSH session and NPM, DNS, authentication and logging. Check ordinary-client denial again before claiming success.
5. If exact restoration is unavailable, remain at the console and stop the rollout. Any narrowly scoped emergency relaxation requires a conscious owner decision, time limit and subsequent revalidation.

The old single policy_in=ACCEPT recovery hint was not a universal rollback: it would not undo a guest deny, NIC/source filter, router or Docker-path change. Keep the complete secure baseline and scope-specific recovery instructions.

## Acceptance checklist and evidence

These are future tests; every result is currently **not tested**.

| Test | Required evidence before acceptance |
|---|---|
| Owner management | Fresh authorized UI/SSH/console access works; an ordinary client cannot reach management surfaces, including alternate/IPv6 paths. |
| Proxy gate | Unauthenticated request is gated; authorized account reaches intended app; denied account stays denied; Authentik failure cannot release protected app content. Retain local app role checks. |
| Direct backends | Ordinary client cannot connect to each of 3001, 3002, 8083, 9000 and 8443 at its actual guest addresses, including aliases/IPv6/direct Docker paths. Changing Host headers must not bypass the network boundary. |
| Required upstreams | NPM can reach all five intended upstreams; Nextcloud can complete HTTPS discovery/token/user-info through Authentik's canonical route; cookies/redirects/logout remain correct. |
| Resolver / DHCP | Approved clients resolve private names over UDP/TCP DNS; unapproved sources are denied; leases renew without collisions or dependency drift. Check client DNS distribution and no forwarding loop. |
| Logging | Approved Docker engines deliver a unique dummy event to the receiver, real source addresses match policy, unauthorized senders are denied. UDP send success alone is not receipt proof. |
| Runtime network | Required ICMP/ICMPv6, MTU, router discovery, return traffic and app-private DB/cache connections work; unused TCP syslog is not broadly exposed. |
| Transport | Client/management certificate and hostname validation succeed before credentials; remaining HTTP upstream risk is explicitly documented; callbacks reconciled in their assigned package. |
| Persistence and rollback | Planned restart/renewal retains addresses and rules, fresh allow/deny checks pass, and a disposable rollback restores the captured known-good state. |
| External boundary | Router/WAN/UPnP and IPv6 exposure reviewed without assuming internal domains provide a firewall. |

Record time, source role/address family, destination/port, expected outcome, observed result and sanitized evidence for each test. A timeout alone can also indicate routing/service failure; establish positive NPM/owner controls and inspect counters/logs before attributing a denial to the firewall. Do not publish tokens, packet payloads, full configs or credentials.

## Decisions still required

Owner/client source sets; router reservation support and conflict-free addresses; actual MACs/leases; installed firewall/Docker backend and flags; effective IPv6 topology; observed syslog/NPM sources after NAT; current admin listeners; protected management transport; available console/recovery method; identity/application compatibility. Any unresolved item blocks the corresponding enforcement step.

Rollback now means discarding/reverting this documentation proposal only. No network state was changed. SEC-001, NET-001 and SEC-003 remain open for implementation and live verification. Separate backup/recovery planning and the earlier identity/NPM proposals remain independent, unapplied work.
