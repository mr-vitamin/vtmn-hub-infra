# Nginx Proxy Manager — routing reference

**Status: October 22, 2026.** The server is powered off. This documents committed configuration and historical exports, not verified running routes. The Compose image is jc21/nginx-proxy-manager:latest; the installed NPM/Nginx versions and generated configuration are unknown.

## Read this before configuring a proxy host

Despite the directory name, the three files in [nginx-snippets/](nginx-snippets/) are **complete historical Nginx reference exports, not paste-ready Advanced-field snippets**. They contain an HTTP-context map, full server blocks, listeners, certificate paths, logs and NPM includes. Keep the exports intact for comparison; do not paste them into Advanced, wrap them in another server block, or install them as additional active virtual hosts.

The [infrastructure reference](../../docs/INFRASTRUCTURE.md#npm-proxy-routes) describes five intended routes. Only docs, inventory and hub have committed Nginx exports. Compose supplies NPM's container, ports and persistent mounts; it does not reconstruct the UI database's proxy hosts or certificate objects.

## Prerequisites and boundaries

The [Compose file](docker-compose.yml) requires an existing external Docker network named proxy on NPM's Docker host. Network creation is a separate, state-changing setup action; inspect existing networks before any approved creation. This local Docker network does not connect separate LXC Docker engines: NPM uses LAN addresses for those upstreams.

Reconcile actual guest addresses before setup; the provisioning script uses DHCP while the exports use fixed historical addresses. Review the [firewall reference](../../proxmox/firewall-setup.md) before later access-control work. Forward-auth protects requests through the proxy; it does not block direct access to published backend ports. No access restriction is implemented by this documentation change.

## Intended routes and source coverage

Addresses below are committed reference values, not current reachability results.

| Client hostname | Intended upstream from NPM | Authentication model | Evidence / missing work |
|---|---|---|---|
| auth.vtmn.internal | HTTP 192.168.0.124:9000 | Authentik login/provider endpoints | Documented route; no committed proxy-host export. Capture the actual host settings before rebuilding. |
| hub.vtmn.internal | HTTP 192.168.0.56:3001 | Authentik forward-auth | [Reference export](nginx-snippets/hub.vtmn.internal.conf). |
| docs.vtmn.internal | HTTP 192.168.0.176:3002 | Authentik forward-auth, then application-local permissions | [Reference export](nginx-snippets/docs.vtmn.internal.conf). Historical alternative Wiki.js identity blueprints also exist; reconcile active state before applying identity changes. |
| inventory.vtmn.internal | HTTP 192.168.0.175:8083 | Authentik forward-auth, then application-local permissions | [Reference export](nginx-snippets/inventory.vtmn.internal.conf). |
| drive.vtmn.internal | HTTP 192.168.0.231:8443 | Nextcloud native OIDC | Documented route; no committed proxy-host export. [Compose](../nextcloud/docker-compose.yml) maps host 8443 to container HTTP 80; port 8443 does not establish upstream HTTPS. |

The DNS [wildcard](../dns/dnsmasq.conf) targets NPM at 192.168.0.31. Intended client HTTPS terminates at NPM; the committed application upstreams use HTTP on the internal network. Do not infer end-to-end TLS.

## Configuration context: what belongs where

| Export content | Context / treatment |
|---|---|
| map $scheme $hsts_header { ... } | Nginx http context. Never put it inside an existing server or location. Do not copy the export's HSTS map to global custom config as part of this package. |
| server { ... }, listen, server_name | Complete virtual-host structure, managed by NPM. Do not nest it in Advanced or create a competing active host from the export. |
| ssl_certificate, ssl_certificate_key, NPM includes and per-host logs | Generated, deployment-dependent scaffolding; configure the matching NPM objects and inspect actual output instead of copying export-specific IDs/paths. |
| location /outpost.goauthentik.io { ... } | Host-specific server child: handles the embedded outpost path, forwarding to Authentik. |
| location / { ... } | Host-specific server child: authenticates ordinary app requests and proxies to that app's backend. |
| location @goauthentik_proxy_signin { ... } | Named server child: internal sign-in redirect handler. |

For the three forward-auth hosts, the **intended host-specific Advanced candidate** is the three complete location blocks listed above, taken together from that host's export, without its outer server wrapper, map, listeners, certificate/log paths or includes. Directives inside each block retain their location context. This identifies the source boundary; it is not a validated installation snippet.

The [current upstream NPM template](https://github.com/NginxProxyManager/nginx-proxy-manager/blob/develop/backend/templates/proxy_host.conf) inserts Advanced content inside a server and conditionally emits its default location. The installed release is unknown. Before use, compare that release's template and generated host file: there must be exactly one intended root location, no competing generated/custom locations, and no unprotected application path. Simply removing the map/server wrapper does not establish correctness. A syntax test alone does not prove authentication covers every path.

NPM [custom include locations](https://nginxproxymanager.com/advanced-config/#custom-nginx-configurations) have different scopes: HTTP includes are distinct from server_proxy.conf, which affects every proxy host. Do not move these host-specific authentication locations into a global include.

NGINX documents [map as http-only](https://nginx.org/en/docs/http/ngx_http_map_module.html#map). Consult the version-matched [Authentik Nginx/NPM integration guidance](https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_nginx/) before assembling configuration. Newer examples can differ from these historical exports; do not silently replace the recorded behavior.

## Preserve the authentication and application destinations

Each forward-auth export has two different proxy_pass destinations:

- The outpost location forwards to http://192.168.0.124:9000/outpost.goauthentik.io for all three hosts. The auth_request subrequest targets /outpost.goauthentik.io/auth/nginx through this location.
- The root location forwards to the individual app address in the route table. Only this backend destination differs by app.

Retain the root auth_request, cookie/header handling, 401 sign-in handling and internal named location as a coherent integration during later review. Do not swap the two upstreams, remove the auth check to fix an error, or send ordinary app traffic to Authentik. The outpost path must handle its own authentication protocol without recursively applying the root auth check; that exception must never forward to an application backend or be broadened into an app-path exemption.

Forward-auth is an access gate, not proof that an app consumes identity headers or grants the correct role. The repository documents local app accounts for Wiki.js/Snipe-IT; Authentik policy/group/MFA enforcement and effective outpost assignments remain unverified.

The auth.vtmn.internal host must serve Authentik's login/provider endpoints without putting Authentik behind its own forward-auth gate. This does not remove Authentik's own authentication or authorization. Inventory its actual NPM settings, external URL, provider/outpost state and callback behavior before rebuilding; the missing export is not a tested configuration.

For drive.vtmn.internal, preserve the documented native OIDC model; do not copy a forward-auth app export onto Nextcloud. Canonical hostname, trusted domains/proxies, HTTPS URL generation, application-side user_oidc settings and callback configuration need an authoritative application setup procedure. The committed trusted-domain values use drive.local rather than drive.vtmn.internal, and historical callback alternatives also exist. Their reconciliation belongs to the application/identity packages; this package neither changes them nor claims login works.

## Custom certificate and generated-file assumptions

The documented design uses an internal CA and a wildcard certificate for *.vtmn.internal. NPM's Custom Certificate UI stores the uploaded leaf certificate, chain as applicable and leaf private key, and attaches a certificate object to each proxy host. **Never upload the CA private key to NPM.** Preserve the existing CA and its recovery material. The committed [CA initializer](../../scripts/create-internal-ca.sh) is not a renewal or recovery procedure and must not be rerun over existing CA material. The separate CA-safety proposal has not been applied to master; do not regenerate a CA to resolve a path mismatch.

All three exports reference /data/custom_ssl/npm-1/fullchain.pem and privkey.pem. The npm-1 identifier is historical, not a portable certificate identity. Log names proxy-host-3/4/5 and relative conf.d/include paths likewise depend on NPM's runtime files. The exports also reference /data/nginx/custom/server_proxy[.]conf; its runtime contents are not committed here.

After any future approved restore, identify the actual certificate object and generated paths instead of forcing them to match the export. Back up NPM's data directory/database and relevant certificate material securely; never commit private keys, raw databases or secret-bearing exports. Validate SANs, issuer/chain, expiry, client trust and selected host certificate. Configure Force SSL consistently with the documented design only after HTTPS and recovery access are checked.

The committed published port 81 is an administration port, not proof of an HTTPS management listener. No management TLS wrapper is defined in Compose. Confirm its actual scheme and restrict administration through the separately reviewed network plan.

## Deferred verification and recovery checklist

No steps below were executed for this documentation package.

1. Inventory installed image/version, real host addresses, NPM database/host settings, custom includes and certificate objects; preserve a secure recoverable backup and console/admin access before any approved edit.
2. Assemble a representative configuration in a disposable environment matching the installed NPM image, with disposable certificates and no production secrets. Include generated locations and dependencies; do not test a fragment in isolation and call the complete host validated.
3. Run that environment's Nginx configuration test before considering any reload. Verify all five hostnames, expected certificate/redirects, correct upstream scheme/port and no duplicate locations. Do not pull/start images automatically to perform this step.
4. In a later approved live test, check unauthenticated, authorized and denied requests for all protected hosts, including alternate paths; check sign-in/cookies/logout, local app permissions and Nextcloud OIDC callbacks. Check that an Authentik outage cannot serve protected app content.
5. Independently test direct backend access against the future network access matrix; proxy auth alone cannot prove bypass prevention.
6. If configuration validation or access tests fail, preserve known-good state. Do not disable authentication as a workaround. Restore only the reviewed previous host settings/certificate mapping with recovery access available; do not overwrite NPM's database or replace CA material blindly.

No routing export, Compose file, certificate or identity policy is changed here. Generated-config syntax and effective authentication remain pending until a matching disposable environment and later authorized live checks are available.
