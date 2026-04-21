# mattmccarthy.io

Personal portfolio website for Matt McCarthy, a full-stack web developer based in Chicago, IL.

Built with plain HTML, CSS, and Bootstrap. Served via Nginx in a Docker container.

## Stack

- **Frontend:** HTML5, CSS3, Bootstrap 5.3, Bootstrap Icons, Google Fonts
- **Server:** Nginx
- **Container:** Docker / Docker Compose

## Project Structure

```
.
├── app
│   ├── favicon.ico
│   ├── index.html                      # Single-page portfolio
│   └── static
│       ├── color-scheme.js             # Light/dark theme logic
│       ├── style.css                   # Custom styles
│       ├── triangles_dark.svg          # Background asset (dark mode)
│       └── triangles_light.svg         # Background asset (light mode)
├── docker-compose.yaml                 # Service definitions
├── LICENSE.md
├── nginx.conf                          # Nginx server configuration
└── README.md

3 directories, 10 files
```

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/)

## Running Locally

```bash
git clone https://github.com/mccarthycode/mmio.git
cd mmio
docker compose up
```

The site will be available at [http://localhost](http://localhost).

To run in the background:

```bash
docker compose up -d
```

To stop:

```bash
docker compose down
```

## License

This repository uses a dual license. See LICENSE.md for full terms.

### MIT License &mdash; Code

- `app/static/color-scheme.js`
- `app/static/style.css`
- `docker-compose.yaml`
- `nginx.conf`

### All rights reserved &mdash; Content

- `app/favicon.ico`
- `app/index.html`
- `app/static/triangles_dark.svg`
- `app/static/triangles_light.svg`

Copyright &copy; 2026 Matt McCarthy.
