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

Static sites can't set custom response headers, so the Content-Security-Policy is a
`<meta http-equiv>` tag in `app/templates/index.html` rather than a Flask header. It no
longer uses a per-request nonce: a nonce baked into a static file would be the same for
every visitor, and the page has no inline scripts for one to protect.

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

To change domains or redirects, edit `app.yaml` and either
let the next push to `main` pick it up, or apply it directly with:

```bash
doctl apps update <app-id> --spec app.yaml
```

Validate spec changes locally before pushing:

```bash
doctl apps spec validate app.yaml
```

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
