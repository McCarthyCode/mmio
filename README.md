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
├── .gitignore
├── Dockerfile
├── LICENSE.md
├── README.md
├── app
│   ├── app.py
│   ├── static
│   │   ├── color-scheme.js
│   │   ├── favicon.ico
│   │   ├── style.css
│   │   ├── triangles_dark.svg
│   │   └── triangles_light.svg
│   └── templates
│       └── index.html
├── docker-compose.dev.yaml
├── docker-compose.yaml
└── nginx
    └── conf.d
        ├── mattmccarthy.io.conf
        ├── mattmccarthy.local.conf
        ├── mattmccarthy.net.conf
        ├── mattmccarthy.org.conf
        ├── mccarthycode.com.conf
        └── redirect-http-to-https.conf

5 directories, 19 files
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

This repository uses a dual license. See [LICENSE.md](LICENSE.md) for full terms.

### Content & Assets &mdash; All Rights Reserved

- `app/favicon.ico`
- `app/index.html`
- `app/static/triangles_dark.svg`
- `app/static/triangles_light.svg`

Copyright &copy; 2026 Matt McCarthy. All rights reserved.

### Code &mdash; MIT License

_All other files_

Copyright &copy; 2026 Matt McCarthy. MIT license.
