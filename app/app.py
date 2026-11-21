import yaml
from flask import Flask, render_template, jsonify, Response
from werkzeug.middleware.proxy_fix import ProxyFix


SITE_URL = 'https://mattmccarthy.io'

SITEMAP_ENTRIES = [
    {'loc': f'{SITE_URL}/'},
    {'loc': f'{SITE_URL}/#about'},
    {'loc': f'{SITE_URL}/#skills'},
    {'loc': f'{SITE_URL}/#experience'},
]

app = Flask(__name__)
app.wsgi_app = ProxyFix(
    app.wsgi_app,
    x_for=1,
    x_proto=1,
    x_host=1,
    x_port=1,
    x_prefix=1
)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/llms.<any(txt, md):ext>')
def llms(ext):
    mimetype = 'text/markdown' if ext == 'md' else 'text/plain'
    return Response(render_template('llms.txt', site_url=SITE_URL), mimetype=mimetype)

@app.route('/robots.txt')
def robots_txt():
    return Response(
        render_template('robots.txt', sitemap_url=f'{SITE_URL}/sitemap.xml'),
        mimetype='text/plain',
    )

@app.route('/sitemap.<any(xml, json, yaml, yml):ext>')
def sitemap(ext):
    if ext == 'xml':
        return Response(
            render_template('sitemap.xml', entries=SITEMAP_ENTRIES),
            mimetype='application/xml',
        )
    if ext == 'json':
        return jsonify(urls=SITEMAP_ENTRIES)
    return Response(
        yaml.dump({'urls': SITEMAP_ENTRIES}, sort_keys=False),
        mimetype='application/yaml',
    )
