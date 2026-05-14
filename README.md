# mattmccarthy.io

Personal portfolio website for Matt McCarthy, a full-stack web developer based in Chicago, IL.

Built with Flask backend, HTML5, CSS3, and Bootstrap. Served via Nginx in a Docker container.

## Stack

- **Frontend:** HTML5, CSS3, Bootstrap 5.3, Bootstrap Icons, Google Fonts
- **Backend:** Python Flask with Gunicorn
- **Server:** Nginx reverse proxy
- **Container:** Docker (multi-stage builds)
- **Registry:** GitHub Container Registry (ghcr.io)
- **CI/CD:** GitHub Actions (automated image builds)
- **Infrastructure:** AWS Lambda, HTTP API Gateway, CloudWatch (TODO)
- **IaC:** AWS SAM CloudFormation (TODO)

## Project Structure

```
❯ tree . -a --gitignore -I .git
.
├── .github
│   └── workflows
│       ├── build-release-image.yml    # Automated image builds
│       └── opencode.yml               # Agent configuration
├── .gitignore
├── app
│   ├── app.py                         # Flask app with CSP nonce generation
│   ├── requirements.txt               # Python dependencies
│   ├── static                         # Scripts, stylesheets, and assets
│   │   ├── color-scheme.js
│   │   ├── favicon.ico                # Proprietary asset (see LICENSE.md)
│   │   ├── style.css
│   │   ├── triangles_dark.svg         # Proprietary asset (see LICENSE.md)
│   │   └── triangles_light.svg        # Proprietary asset (see LICENSE.md)
│   └── templates                      # Jinja2 templates
│       └── index.html                 # Proprietary content (see LICENSE.md)
├── docs
│   └── actions.md
├── docker
│   ├── .env
│   │   ├── development
│   │   │   └── www.env                # Development app settings
│   │   └── staging
│   │       └── www.env                # Staging app settings
│   ├── build-image.sh                 # Local build script
│   ├── compose.dev.yml                # Development compose configuration
│   └── compose.yml                    # Production compose configuration
├── Dockerfile                         # Multi-stage build for Flask app
├── LICENSE.md
├── nginx
│   └── conf.d                         # Configurations for domains & redirects
│       ├── mattmccarthy.io.conf
│       ├── mattmccarthy.local.conf
│       ├── mattmccarthy.net.conf
│       ├── mattmccarthy.org.conf
│       ├── mccarthycode.com.conf
│       └── redirect-http-to-https.conf
└── README.md

13 directories, 27 files
```

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/)
- [Python 3.11+](https://www.python.org/) (for testing and development)

## Development

### Running Locally

Ensure you add the following line to `/etc/hosts` (or `C:\Windows\System32\drivers\etc\hosts` on Windows):

```
127.0.0.1 mattmccarthy.local www.mattmccarthy.local
```

Clone the repository and run Docker Compose.

```bash
git clone https://github.com/mccarthycode/mmio.git
cd mmio
docker compose -f docker/compose.dev.yml up
```

The site will be available at [https://mattmccarthy.local](https://mattmccarthy.local).

To run in the background:

```bash
docker compose -f docker/compose.dev.yml up -d
```

To stop:

```bash
docker compose -f docker/compose.dev.yml down
```

## GitHub Actions

See [docs/actions.md](docs/actions.md).

## License

This repository uses a dual license. See [LICENSE.md](LICENSE.md) for full terms.

### Content & Assets — All Rights Reserved

- `app/static/favicon.ico`
- `app/static/triangles_dark.svg`
- `app/static/triangles_light.svg`
- `app/templates/index.html`

Copyright © 2026 Matt McCarthy. All rights reserved.

### Code — MIT License

All other files

Copyright © 2026 Matt McCarthy. MIT license.
