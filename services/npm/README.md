# Nginx Proxy Manager

## Prerequisite

The compose file references an external Docker network that must exist before `docker compose up`:

```bash
docker network create proxy
```

## Forward-auth setup (Wiki.js, Snipe-IT, Homepage)

These three apps don't have native OIDC support wired in (or, for Wiki.js, it turned out unreliable in practice — see `docs/INFRASTRUCTURE.md`), so they're gated at the network level using Authentik's embedded proxy outpost instead. The nginx config snippets in `nginx-snippets/` need to be pasted into each proxy host's **Advanced** tab in the NPM UI — this isn't exposed via docker-compose or NPM's regular UI fields.

**Important gotcha we hit twice**: each snippet has *two* `proxy_pass` lines — one inside `location /outpost.goauthentik.io` that must always point at Authentik (`http://<authentik-ip>:9000/outpost.goauthentik.io`), and one inside `location /` that points at the actual backend app. Only the second one changes per-host. Mixing these up either sends traffic to the wrong app or breaks the auth check entirely.

## Custom SSL certificate

The wildcard cert for `*.vtmn.internal` (see `scripts/create-internal-ca.sh`) gets uploaded via **SSL Certificates → Add SSL Certificate → Custom** in the NPM UI, then attached to each proxy host with Force SSL enabled. NPM doesn't expose certificate upload via docker-compose or its REST API in a way that's practical to script here — do it through the UI.
