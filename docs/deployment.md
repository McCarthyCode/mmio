# Deployment

## Production: DigitalOcean App Platform

Production hosting is a single DigitalOcean App (`app.yaml` at the repo root, App
Platform's native spec format). DO builds the image directly from the root `Dockerfile`
on every push to `main` (`deploy_on_push: true`) — there is no GitHub Actions workflow,
image registry, or manual build step in the deploy path.

DO's managed layer also terminates TLS and does domain routing, replacing what an
in-repo Nginx container used to do:

- `mattmccarthy.io` (PRIMARY) and `www.mattmccarthy.io` (ALIAS) serve the app directly.
- `mattmccarthy.net`, `mattmccarthy.org`, `mccarthycode.com`, and their `www.` variants
  301-redirect to `https://mattmccarthy.io` via `app.yaml`'s `ingress.rules`, matching
  the previous Nginx `return 301` behavior.

To change environment variables, instance size, or domains, edit `app.yaml` and either
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
bind-mounts `./app` into the container and runs Flask's debug server directly (no Nginx
locally either — the container listens on 8080, matching what DO expects in
production).

To run in the background: `docker compose up -d`. To stop: `docker compose down`.

## OpenCode

For more info, look at https://github.com/McCarthyCode/mmio/issues/9.
