"""Render the Flask app to plain files for App Platform's static site component.

Usage: python freeze.py [output_dir]   (default: build)
"""
import shutil
import sys
from pathlib import Path

from app import app

# Every non-static route, mapped to the file it becomes.
PAGES = {
    '/': 'index.html',
    '/llms.txt': 'llms.txt',
    '/llms.md': 'llms.md',
    '/robots.txt': 'robots.txt',
    '/sitemap.xml': 'sitemap.xml',
    '/sitemap.json': 'sitemap.json',
    '/sitemap.yaml': 'sitemap.yaml',
    '/sitemap.yml': 'sitemap.yml',
}


def freeze(out_dir):
    out = Path(out_dir)
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(app.static_folder, out / app.static_url_path.strip('/'))

    client = app.test_client()
    for url, filename in PAGES.items():
        response = client.get(url)
        if response.status_code != 200:
            sys.exit(f'{url} returned {response.status_code}')
        (out / filename).write_bytes(response.data)
        print(f'{url} -> {out / filename}')


if __name__ == '__main__':
    freeze(sys.argv[1] if len(sys.argv) > 1 else 'build')
