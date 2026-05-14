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
│       └── opencode.yml              # Agent configuration
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

12 directories, 25 files
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

## Building Release Images

This project uses automated image building via GitHub Actions, decoupled from production infrastructure. Release images are built and published to the GitHub Container Registry on every push and pull request.

### Automated Builds (GitHub Actions)

The `build-release-image.yml` workflow automatically:

1. **Builds** optimized multi-stage Docker images
2. **Tags** images by branch, semantic version, and commit SHA
3. **Publishes** images to `ghcr.io` (GitHub Container Registry)
4. **Scans** images for security vulnerabilities (Trivy)
5. **Caches** layers for faster rebuilds

The workflow triggers on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Tagged releases (v*)

### Building Images Locally

For local development and testing, use the build script:

```bash
./docker/build-image.sh [ENVIRONMENT] [TAG]
```

Examples:

```bash
# Build for development
./docker/build-image.sh development dev

# Build for staging
./docker/build-image.sh staging v1.0.0

# Build for production
./docker/build-image.sh production v1.0.0
```

### Environment Configuration

Environment-specific settings are managed through `./docker/.env/*`/www.env files:

- `./docker/.env/development/www.env` - Development settings (debug enabled, 1 worker)
- `./docker/.env/staging/www.env` - Staging settings (testing-optimized, 2 workers)
- `./docker/.env/production/www.env` - Production settings (optimized, 4 workers)

Load environment settings before building:

```bash
source ./docker/.env/development/www.env
./docker/build-image.sh development
```

### Multi-Stage Build Optimization

The Dockerfile uses a two-stage build process for efficiency:

1. **Builder Stage:** Compiles Python dependencies without build tools
2. **Runtime Stage:** Contains only runtime dependencies, reducing image size

Benefits:
- Smaller final image size
- Faster deployments
- Reduced attack surface
- Optimized caching

### Image Scanning

All published images are scanned for vulnerabilities using Trivy. Results are uploaded to GitHub Security tab for monitoring.

### Registry Access

Published images are available at:

```
ghcr.io/mccarthy-code/mmio-www:latest
ghcr.io/mccarthy-code/mmio-www:main
ghcr.io/mccarthy-code/mmio-www:v1.0.0
```

To pull locally:

```bash
docker pull ghcr.io/mccarthy-code/mmio-www:latest
```

### CI/CD Integration

Release images are built outside production infrastructure:
- ✅ Automated builds on every commit
- ✅ No manual deployment commands needed
- ✅ Decoupled from live production environment
- ✅ Version control for all builds
- ✅ Security scanning included

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
