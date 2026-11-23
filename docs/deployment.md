# Deployment

## Production: DigitalOcean App Platform

Production hosting is a single DigitalOcean App (`app.yaml` at the repo root, App
Platform's native spec format) with one **static site** component, which keeps it on
App Platform's free tier (up to three static-only apps). On every push to `main`
(`deploy_on_push: true`), App Platform's Python buildpack installs
`app/requirements.txt` and runs `python freeze.py build` in `app/`. That script
renders every Flask route once (`/`, `llms.txt`/`.md`, `robots.txt`, and the four
sitemap formats) plus `static/` into `app/build/`, and App Platform publishes those
files. Nothing runs at request time, and there's no GitHub Actions workflow or image
registry in the deploy path.

When you add a Flask route, add it to `PAGES` in `app/freeze.py`, or it won't exist
in production.

### Content-Security-Policy

Cloudflare injects an inline JavaScript Detections script into every HTML page. It
only adds a nonce to that script by parsing the CSP *response header*; a nonce in a
`<meta>` tag isn't supported (see issue #1, which is why the old Flask app generated a
nonce per request). Static sites can't set headers, so a Cloudflare Worker on the
`mattmccarthy.io` zone does it instead (`cloudflare/csp-worker/`). For each HTML
response it:

- generates a fresh nonce;
- removes the `<meta http-equiv="Content-Security-Policy">` tag;
- puts the nonce on every `<script>`, including the one Cloudflare injected;
- sends the policy as a header whose `script-src` is just `'nonce-…' 'strict-dynamic'`;
- sets `Cache-Control: private, no-store`, so a nonce is never served twice.

`'strict-dynamic'` is required: the injected script creates a second inline script
inside a hidden iframe, and only `'strict-dynamic'` trusts scripts created by a nonced
script. Because every `<script>` gets the nonce, the header's `script-src` has no
`'self'` or host allowlist; browsers would ignore one next to `'strict-dynamic'`
anyway. Other responses pass through unchanged.

The meta tag stays in `app/templates/index.html` as the policy for the DO default
domain and local dev. When you add a style, font or connect host, update both the meta
tag and `POLICY` in `cloudflare/csp-worker/src/index.js`. A new script host goes in the
meta tag only; the Worker's nonce covers it.

Deploy the Worker from `cloudflare/csp-worker/` with `npx wrangler login` and then
`npx wrangler deploy`. App Platform doesn't deploy it. Its routes are
`mattmccarthy.io/*` and `www.mattmccarthy.io/*`; the redirect domains don't need it. In
the Cloudflare dashboard, set the routes' request-limit failure mode to **Fail open**:
past the Free plan's 100,000 requests a day, requests then skip the Worker and fall back
to the meta tag instead of failing. To roll back, remove the routes or run
`npx wrangler delete`.

App Platform serves static sites from its CDN edge with `Cache-Control` set to 24
hours at the edge and 10 seconds in browsers. Each deploy invalidates the edge cache.

DO's managed layer also terminates TLS and does domain routing, replacing what an
in-repo Nginx container used to do:

- `mattmccarthy.io` (PRIMARY) and `www.mattmccarthy.io` (ALIAS) serve the site directly.
- `mattmccarthy.net`, `mattmccarthy.org`, `mccarthycode.com`, and their `www.` variants
  301-redirect to `https://mattmccarthy.io` via `app.yaml`'s `ingress.rules`, matching
  the previous Nginx `return 301` behavior.

To preview exactly what production will serve:

```bash
cd app && pip install -r requirements.txt && python freeze.py build
python -m http.server 8000 -d build
```

Pushing to `main` rebuilds the code against the spec App Platform already has
stored. It doesn't read `app.yaml` from the repo. To change the components,
domains or redirects, edit `app.yaml`, merge it, then apply it explicitly:

```bash
doctl apps spec validate app.yaml
doctl apps update <app-id> --spec app.yaml
```

Until that runs, App Platform keeps using the previous spec.

### History

This setup replaced a manual EC2 + Nginx flow (`docker compose down && docker compose
up -d` on the host, TLS certs mounted from an untracked `nginx/ssl/` directory). See
issues #7, #8, #28, #35 and their linked PRs for the full migration history — #35 is
the issue this deployment closes.

## Local development

```bash
git clone https://github.com/mccarthycode/mmio.git
cd mmio
docker compose up
```

The site is available at [http://localhost:8080](http://localhost:8080). `docker-compose.yaml`
bind-mounts `./app` into the container and runs Flask's debug server directly. The
`Dockerfile` is now only used for this local setup; production doesn't build it.

To run in the background: `docker compose up -d`. To stop: `docker compose down`.

## OpenCode

> [!CAUTION]
> DEPRECATED ([#32](https://github.com/McCarthyCode/mmio/issues/32))

For more info on initial implementation, see [#9](https://github.com/McCarthyCode/mmio/issues/9).
