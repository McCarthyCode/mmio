# mattmccarthy.io

Personal portfolio website for Matt McCarthy, a full-stack web developer based in Chicago, IL.

Built with Flask backend, HTML5, CSS3, and Bootstrap. Deployed to DigitalOcean App Platform.

## Stack

- **Frontend:** HTML5, CSS3, Bootstrap 5.3, Bootstrap Icons, Google Fonts
- **Backend:** Python Flask with Gunicorn
- **Container:** Docker (multi-stage build)
- **Infrastructure:** DigitalOcean App Platform — builds directly from the `Dockerfile`
  on every push to `main`, terminates TLS, and routes all custom domains natively (no
  Nginx or image registry in the loop)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/)
- [Python 3.11+](https://www.python.org/) (for testing and development)

## Development

### Running Locally

Clone the repository and run Docker Compose.

```bash
git clone https://github.com/mccarthycode/mmio.git
cd mmio
docker compose up
```

The site will be available at [http://localhost:8080](http://localhost:8080).

To run in the background:

```bash
docker compose up -d
```

To stop:

```bash
docker compose down
```

## Deployment

See [docs/deployment.md](docs/deployment.md).

## License

This repository uses a dual license. See [LICENSE.md](LICENSE.md) for full terms.

### Content & Assets — All Rights Reserved

- `app/static/favicon.ico`
- `app/static/headshot.jpg`
- `app/static/triangles_dark.svg`
- `app/static/triangles_light.svg`
- `app/templates/index.html`

Copyright © 2026 Matt McCarthy. All rights reserved.

### Code — MIT License

All other files

Copyright © 2026 Matt McCarthy. MIT license.
