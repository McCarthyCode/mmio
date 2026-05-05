from secrets import token_urlsafe

from flask import Flask, render_template, g
from werkzeug.middleware.proxy_fix import ProxyFix


app = Flask(__name__)
app.wsgi_app = ProxyFix(
    app.wsgi_app,
    x_for=1,
    x_proto=1,
    x_host=1,
    x_port=1,
    x_prefix=1
)

@app.before_request
def set_nonce():
    g.nonce = token_urlsafe(32)

@app.after_request
def set_csp(response):
    response.headers['Content-Security-Policy'] = (
        f"default-src 'self'; "
        f"script-src 'self' 'nonce-{g.nonce}' https://cdn.jsdelivr.net https://static.cloudflareinsights.com; "
        f"style-src 'self' https://cdn.jsdelivr.net https://fonts.googleapis.com; "
        f"font-src 'self' https://cdn.jsdelivr.net https://fonts.gstatic.com; "
        f"connect-src 'self' https://cdn.jsdelivr.net https://cloudflareinsights.com; "
        f"object-src 'none';"
    )
    return response

@app.route('/')
def index():
    return render_template('index.html', nonce=g.nonce)
