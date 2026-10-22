# Application operations and secret inputs

**Source proposal — October 22, 2026.** Server powered off; no installed application/Compose version, persistent setting, account, permission, scheduler or login was verified. Findings APP-001, APP-002, DOC-002, DOC-003 and OPS-004 need the source corrections and future checks below. No credential, trust domain, proxy policy or live state is changed here.

## Intended identity and access model

| Service | Repository-supported intended model | What remains unknown |
|---|---|---|
| Wiki.js / docs | Authentik forward-auth at NPM, then separate local Wiki.js users and application groups/page rules | Actual strategies/accounts, group membership, guest access and active conflicting historical blueprints. |
| Snipe-IT / inventory | Forward-auth, then local app accounts and granular permission groups | Actual permissions, individual overrides and admin flags. |
| Homepage / hub | Proxy SSO gate; no individual Homepage account is required by this design | Effective gate/allowed hosts and direct-backend reachability. |
| Nextcloud / drive | Native user_oidc with Authentik, plus Nextcloud authorization | Installed app/provider settings, user provisioning/linking, claims, tokens and permissions. |
| Authentik | Central authentication/provider/outpost and its own authorization policies | Actual version, MFA, group bindings and stored outpost membership. Groups in documentation are not exported enforcement. |

Forward-auth does not automatically create a local Wiki.js/Snipe-IT identity, synchronize passwords or grant roles. Do not enable Wiki.js OIDC/self-registration/group mapping as a step of this local-account model. Historical OIDC/revert/outpost files conflict; inventory stored state and reconcile through the [integrated identity guidance](../services/authentik/README.md) before application. No existing user is migrated or disabled here.

The [permission guide](../scripts/configure-app-permissions.md) and [onboarding template](ONBOARDING-TEMPLATE.md) describe the intended application authorization process and future positive/negative checks. Test SSO and app permissions independently.

## Nextcloud: canonical host and reverse proxy (APP-001)

Intended public application URL inside this LAN: **https://drive.vtmn.internal**. The source still sets NEXTCLOUD_TRUSTED_DOMAINS to drive.local and 192.168.0.231. This package preserves that value because changing it without the effective persistent configuration, version and recovery access could break an existing deployment. It is a known mismatch, not a fixed runtime setting.

The [Nextcloud Compose file](../services/nextcloud/docker-compose.yml) publishes 8443:80, so the documented NPM upstream is HTTP 192.168.0.231:8443. Port 8443 alone does not establish backend TLS. auth.vtmn.internal should reach Authentik at HTTP 192.168.0.124:9000. Both proxy-host exports are missing. The three other Nginx files are complete historical exports, not ready-to-paste Advanced snippets; the [NPM context correction](../services/npm/README.md) is integrated locally, with deployment and actual generated-config verification pending.

Before a later approved change:

1. Capture the actual version/image, effective config.php and other loaded config fragments, database/app/provider settings, real proxy source after Docker/NAT and a protected recovery set. Do not publish config dumps or put a *.config.php backup into the active config directory, where it may be loaded.
2. Add the exact canonical host to trusted_domains through the selected version/image's supported mechanism after reviewing existing entries. Do not replace the whole configuration, allow arbitrary hosts or confuse trusted_domains with trusted_proxies.
3. Set trusted_proxies narrowly to the observed NPM connection source(s), using historical 192.168.0.31 only after verification. Never trust all clients/the whole LAN to supply forwarded identity. Confirm the real client address and proxy header handling; an IP-only allow does not encrypt the upstream.
4. Verify automatic host/protocol detection. If overrides are necessary, version-supported intended values are overwritehost=drive.vtmn.internal, overwriteprotocol=https and overwrite.cli.url=https://drive.vtmn.internal, with overwritecondaddr limited to the actual proxy path where appropriate. These are targets to review, not a complete config.php or unconditional write. Preserve working paths/webroot and unrelated settings.
5. Ensure client and Nextcloud-to-IdP connections validate the internal CA, hostname and chain. Do not disable TLS verification. Verify NPM auth/drive host objects and actual certificates, headers, redirects and upstreams using a disposable configuration before a future rollout.
6. Test approved hostname access, rejection of an untrusted Host header, generated links, CLI/background URLs, client-IP attribution and direct-backend restrictions, with console/local recovery available.

Primary guidance: [trusted domains/config loading](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/config_sample_php_parameters.html) and [reverse-proxy configuration](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/reverse_proxy_configuration.html). Match these to the installed version; the current online manual is not installed-state evidence.

## Nextcloud: application-side OIDC

The preserved [historical provider definition](../services/authentik/history/nextcloud-sso.yaml) names client_id nextcloud-vtmn, application slug nextcloud and HTTPS redirect https://drive.vtmn.internal/apps/user_oidc/code. It also contains historical HTTP alternatives. Its historical literal placeholder is not active desired state. The [inactive candidate and compatibility gate](../services/authentik/README.md) require installed-version validation; Compose's new required-value guards do not render Authentik blueprints.

Required version-matched setup record, before any future application:

| Item | Intended record / decision |
|---|---|
| Server and user_oidc versions | Actual installed versions and their compatibility; do not install/upgrade the app as part of this source proposal. |
| Provider issuer/discovery | Copy the installed Authentik provider's advertised issuer/discovery URL and verify its HTTPS identity. A slug suggests a path but is not evidence of a working endpoint. |
| Client and redirect | Existing client ID nextcloud-vtmn and matching existing secret recovered securely; validate the exact HTTPS callback against the installed app. Never create a new secret merely to fill the example. |
| Claims and local identity | Stable unique identifier/sub, verified identity/email semantics, display-name mappings and necessary scopes. Do not blindly link existing accounts by mutable/unverified email or invent a groups-to-permissions binding. |
| Provisioning | Explicitly choose/version-check whether a new authorized user can provision, how existing accounts are linked, quotas/groups and denial behavior. Automatic creation is not assumed. |
| Recovery and sessions | Preserve a protected owner recovery path; test sign-in, denied access, logout and existing sessions/tokens. Do not delete providers to troubleshoot identity linking. |

Configure through the installed app's supported UI or version-matched tooling without placing secrets into shell history, process listings, rendered files or Git. Consult [user_oidc's maintained documentation](https://github.com/nextcloud/user_oidc) and verify command/options against the installed release. Its self-signed/skip-verification workaround is not a substitute for establishing CA trust.

Retire unused HTTP callback/domain alternatives only after the canonical flow, local recovery and all dependent clients are proven. No callback, hostname or persisted provider is changed here.

## Nextcloud: periodic background work (APP-002)

The committed stack has app, db and redis, with no cron service or host scheduling procedure. A real host job/persistent app setting may exist outside Git; inventory before choosing anything.

Proposed minimal method: one scheduler on the Nextcloud LXC's Docker host invokes cron.php inside the existing app container, using the correct web-process UID for the selected image (commonly www-data for the Debian Apache variant) and non-interactive execution. It uses the app container's existing code/config/data mounts rather than a second unsynchronized app copy. Schedule about every five minutes as the [Nextcloud background-job guide](https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/background_jobs_configuration.html) recommends, after installed-version confirmation. No cron entry or command is installed here.

Record the absolute Compose/project paths, actual container/service, executable/script path (the committed image uses /var/www/html layout), UID, timezone/environment, exit/error capture, bounded runtime/overlap policy and app's selected background mode. Inventory host cron, timers and any existing cron container first; use one authority, with locking/non-overlap rather than duplicate schedulers. Do not run as root to fix an unknown ownership problem, launch a new image on each tick, or embed secrets in a cron command.

If a sidecar is chosen later instead, separately review its exact matching image, entrypoint/user, shared code/config/data volumes, database/network access and resource impact. It is not part of this proposal. Verify successful execution/last-run status and housekeeping while no user visits the site, file/DB permissions, error handling and restart persistence. Switching mode without a functioning scheduler is incomplete.

## Required Compose inputs and secret continuity (OPS-004)

The four application Compose candidates now use the supported required/nonempty interpolation operator for existing variables; no value or image behavior is changed when valid inputs are supplied.

| Stack | Required Compose inputs |
|---|---|
| Authentik | AUTHENTIK_SECRET_KEY, AUTHENTIK_DB_PASSWORD |
| Wiki.js | WIKIJS_DB_PASSWORD |
| Snipe-IT | SNIPEIT_APP_KEY, SNIPEIT_DB_PASSWORD, SNIPEIT_DB_ROOT_PASSWORD |
| Nextcloud | NEXTCLOUD_DB_PASSWORD, NEXTCLOUD_DB_ROOT_PASSWORD |

Eight distinct variables appear in 14 interpolation sites. They are all blank in [.env.example](../.env.example). Copy only the variables needed by the selected service into a private explicitly selected env source; do not send every stack every secret. OIDC variables in the example are application/provider setup inputs and are not wired into these Compose guards. The inactive identity proposal has its own compatibility gate.

An unset or empty required input fails configuration before deployment. Whitespace, placeholder text, weak secrets, wrong format or a secret inconsistent with an existing database still pass a nonempty check. Use the [Compose interpolation rules](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/) and verify the installed Compose supports them before later use. Shell values can override env-file values; check the selected source without printing credentials. Dollar/quote handling must be tested for that source/version, not guessed.

- **SNIPEIT_APP_KEY:** recover and preserve the exact existing key with its database. It protects encrypted fields; replacement can make them unreadable. For a genuinely new installation only, use the selected release/image's supported key-generation method under separate approval; do not substitute generic random hex, change prefixes or re-encode an existing key. See [key generation/custody](https://snipe-it.readme.io/docs/generate-your-app-key).
- **AUTHENTIK_SECRET_KEY:** preserve the original value and database/media recovery context. For new setup, follow the selected release's key requirements; this guard does not establish strength/format or authorize rotation.
- **DB passwords/root passwords:** preserve values matching initialized DB users. Editing an environment value does not reliably rotate an existing database password; plan coordinated changes separately. Use supported strings/encoding for the exact image/client and keep root/application values distinct.
- **OIDC secrets:** provider and application must use the same existing secret through a version-supported secure mechanism. Do not interpret a literal blueprint placeholder as working interpolation or generate a replacement during rebuild.

All actual .env files, app config/database dumps, keys and reset links remain private. Do not display rendered real Compose output; prefer configuration-only quiet checks on the trusted host and handle errors privately. A quiet parse is not a secret-format, application or live-SSO test. The offline regression suite uses an explicit empty env file, restricted environment and public dummy values only.

## Evidence, future tests and rollback

Before later approved setup: record versions, actual persistent configuration/accounts/roles, valid recovery material and local owner access. Review the integrated identity/NPM documentation and network/version/backup plans as undeployed runtime dependencies; do not apply historical setup commands or direct SQL to “make the docs true.”

Required future acceptance: canonical Nextcloud HTTPS/Host/proxy tests; allowed/denied/new/existing-user OIDC and identity linking; cron last-run without UI visits; Wiki.js local account/group/page scope and denied admin actions; Snipe-IT granular allow/deny and existing key continuity; Homepage proxy gate; session/token and app-local offboarding checks. No one of these is established by Compose parsing.

Current status: source guard/doc corrections prepared, offline dummy configuration checks recorded separately; application setup/authorization/cron and live verification pending. No account, permission, secret, scheduler or trusted proxy/domain was altered.

Rollback now: discard/revert the isolated source proposal. A later source revert removes input guards only; it cannot undo actual settings, users or database changes. Those require captured prior state and separately approved recovery. Never restore credentials blindly, rerun a CA initializer or delete user data as rollback.
