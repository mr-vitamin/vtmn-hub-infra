# Authentik identity configuration handoff

**Status:** reviewed source proposal, October 21, 2026. The server is powered off. No identity state has been applied, upgraded, tested against Authentik, or verified live.

This package addresses IAM-001, IAM-002 and IAM-003. It separates historical inputs from a single proposed architecture and makes compatibility/activation gates explicit. It does not provide a ready-to-deploy identity migration.

## Authoritative proposed architecture

The [infrastructure reference](../../docs/INFRASTRUCTURE.md) and [NPM notes](../npm/README.md) identify forward-auth as the final documented Wiki.js access model. The alternative Wiki.js OIDC blueprint is an earlier experiment, not a second active desired state.

| Application | Proposed authentication path | Application authorization / account boundary |
|---|---|---|
| Wiki.js / Docs | Authentik forward-auth through NPM | Local Wiki.js account and restricted application group permissions; proxy headers do not provision an account. |
| Snipe-IT / Inventory | Authentik forward-auth through NPM | Local account and Snipe-IT Operator permissions remain required. |
| Homepage / Hub | Authentik forward-auth through NPM | No individual Homepage account is defined in this repository. Actual version-specific gates remain unverified. |
| Nextcloud / Drive | Native OIDC with Authentik | Application-side user_oidc, provisioning, trusted hostname/proxy, and app permissions require verification; a provider alone is insufficient. |

This is source-backed intended architecture, not evidence of currently applied providers or successful logins. If future runtime inventory contradicts the reference, stop and review the discrepancy rather than forcing the proposal onto it.

## Directory layout and activation boundary

- [blueprints/local/](blueprints/local/README.md): the existing Compose discovery mount. It is deliberately empty of project YAML while compatibility and migration state are unknown.
- [history/](history/README.md): all six original blueprint files preserved unchanged, outside the mounted directory. These are historical/reference inputs, not deployment instructions.
- [candidates/forward-auth.yaml.example](candidates/forward-auth.yaml.example): one review-only blueprint owns the Docs, Inventory and Hub providers/applications and one embedded-outpost assignment.
- [candidates/nextcloud-sso.yaml.example](candidates/nextcloud-sso.yaml.example): gated Nextcloud example using documented !Env lookup.
- [candidates/hub-branding.yaml.example](candidates/hub-branding.yaml.example): optional branding reference, separate from authentication.
- [candidates/compose-secret-injection.yml.example](candidates/compose-secret-injection.yml.example): review-only environment-wiring example for server and worker. It is not named compose.override.yml and is not loaded by ordinary Compose discovery.

The integrated Compose proposal retains the ./blueprints/local mounts and adds required/nonempty guards for the existing base inputs. Images, service roles and supplied-input models remain unchanged. Do not broaden that mount to include history or candidates, and do not copy every historical file into local. Candidate suffixes and placement outside the mount provide the primary activation separation. Their instantiate:false labels are defense in depth, not a substitute for release compatibility checks or a safety guarantee on an unknown version.

Only the consolidated forward-auth candidate should own the three known applications/providers and embedded-outpost list. Its list represents only repository-known providers. **Do not apply it until the actual outpost inventory is known:** any unrelated live memberships must be preserved explicitly. Do not apply historical outpost writers afterward.

No candidate is automatically applied by this source package. No objects are deleted or disabled in Authentik by moving files in Git.

## Compatibility gate — unresolved

The installed server/worker release is unknown. Both base images use latest, which does not identify the installed version. This package changes neither image, PostgreSQL, Redis, nor any other service runtime setting.

Current primary documentation describes [!Env](https://docs.goauthentik.io/customize/blueprints/v1/tags/), [discovery and instantiation](https://docs.goauthentik.io/customize/blueprints/), and [manual blueprint import/instances](https://docs.goauthentik.io/customize/blueprints/working_with_blueprints/). This establishes the proposed mechanism is vendor-documented today, **not** that it is compatible with the unavailable installation.

Before activation, establish and record:
1. Exact installed Authentik server/worker image versions/digests and their matching documentation.
2. Support for !Env and blueprint labels, the existing model fields, redirect URI schema, named default flows/signing key, and embedded-outpost identifiers.
3. Which process evaluates the blueprint; the example supplies the same existing secret to server and worker to avoid relying on a guessed executor.
4. Existing application/provider links, outpost memberships, group policies, flow bindings, and managed blueprint instances.
5. An isolated same-version test environment and recoverable backup/export. Do not pull latest merely to make the example work.

If compatibility is not established, leave local empty and keep the examples inactive. Do not install an unapproved version, substitute guessed model fields, or activate a partially verified identity state.

## Secret injection proposal — not activated

Plain \${NAME} in a mounted YAML file is literal content; Compose does not render that separate file.

The Nextcloud candidate uses `client_secret: !Env NEXTCLOUD_OIDC_CLIENT_SECRET`. The separate Compose example passes that variable with a required/nonempty guard to both server and worker. Neither the candidate nor the overlay is loaded by default. No new OIDC secret is added to the base Compose environment; only guards for its existing required inputs are integrated. OIDC wiring remains inactive until the installed-release gate is satisfied.

Use the **existing matching provider/client secret** through the approved private configuration path; this package does not generate or rotate one. Do not put real values into tracked YAML, rendered blueprints, test output, PR descriptions, or the environment example. Avoid dumping resolved Compose configuration when real variables are loaded.

Environment lookup alone does not enforce strength, match the application's stored value, or rotate a previously applied placeholder. If a literal placeholder was actually used, treat correction as a separately coordinated provider/client credential change with a tested recovery plan; do not silently replace it while the server is unavailable.

Wiki.js OIDC is historical and has no new secret-injection wiring. Its old placeholder is retained only as historical evidence; do not import that file.

The Nextcloud example preserves the prior redirect entries, including HTTP alternatives. This is not an endorsement of those alternatives. Canonical hostname, trusted proxy/OIDC relying-party setup, HTTPS-only callback cleanup and app job configuration require the application/network packages and later testing. No redirect or routing behavior is changed here.

## Authentication is not authorization

Forward-auth verifies an identity at NPM's proxy boundary; it does not establish application roles, remove local logins, or block direct backend access. The network access-control package must address bypass paths. Application permission checks remain necessary.

The repository names owners/operators and a break-glass admin group but does not export complete creation/membership, application access bindings, MFA enrollment/enforcement, session lifetimes or recovery policies. policy_engine_mode:any is not a group allowlist. **This package creates no groups, policies, bindings, MFA stages, or admin permissions.**

Requirements still to design/verify:
- Intended applications and actions for owners/operators, including denial cases for other authenticated users.
- Explicit MFA requirements, enrollment/recovery handling and an owner-tested break-glass path.
- Wiki.js local group membership and Snipe-IT permission templates, including denied delete/manage/user-admin actions.
- Nextcloud account provisioning and role behavior after OIDC login.
- Account disable/offboarding: IdP sessions/tokens, local application sessions/accounts, app passwords/API tokens and access to shared data. Disabling the IdP account alone is not proof every application session is revoked.
- Secure onboarding delivery with no reset links or populated user records committed.

The [permission guide](../../scripts/configure-app-permissions.md) now describes local Wiki.js/Snipe-IT accounts and application capabilities. This source correction does not establish actual group membership, guest access, MFA or permissions; test those separately.

## Future migration and rollback checklist — do not execute offline

- [ ] Obtain explicit deployment authorization and owner console/recovery access.
- [ ] Record installed releases and perform the compatibility checks above.
- [ ] Securely back up/export identity DB, configuration, application/provider associations, outpost memberships, flow/policy bindings and relying-party settings.
- [ ] Inventory existing stored/file blueprint instances. Disable conflicting reapplication deliberately in a reviewed maintenance step; file moves do not reliably remove every prior instance or undo its objects.
- [ ] Review application uniqueness/identifiers; reconcile duplicate or renamed objects before applying anything.
- [ ] Preserve all unrelated outpost memberships; confirm correct proxy/application URLs and client addresses.
- [ ] In an isolated same-version instance, verify environment lookup with dummy values without displaying real secrets; reject missing/incorrect values.
- [ ] Test a one-time candidate import, then the intended repeated-application workflow twice. Check provider links and outpost membership remain stable through discovery.
- [ ] Test allow/deny cases, local app permissions, login/logout, disabled accounts, MFA requirements and recovery. Do not claim success from YAML parsing alone.
- [ ] Only then decide whether to promote a reviewed YAML file into local and manage a matching instance. Never bulk-enable history.
- [ ] If identity access breaks, use the reviewed owner recovery path, disable the new instance and restore recorded associations/provider membership and matching app settings. A Git revert alone does not revert database mutations or a secret change.
- [ ] Keep previous credentials/recovery records securely until the authorized transition is verified; never print them to a log.

No live steps in this checklist were performed.

## Offline validation

[Static proposal tests](../../tests/test_authentik_layout.py) check layout separation, consolidated object ownership, provider/application references, historical file presence and the gated secret-wiring example.

The tests use installed Docker Compose only as an offline YAML parser, wrapping data in an extension field. No Docker Engine or Authentik is contacted. YAML tags remain structural values; **!Env/!Find/!KeyOf are not evaluated**, and model/API/DB/schema compatibility is not proven.

The examples and all preserved historical files must remain review-only until the compatibility and migration gates are satisfied.
