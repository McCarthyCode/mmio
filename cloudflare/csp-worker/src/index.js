// Restores a per-request CSP nonce in front of the App Platform static site.
//
// Cloudflare injects an inline JavaScript Detections script into HTML pages. It
// adds a nonce to that script only by parsing the CSP *response header*; a nonce
// in a <meta> tag isn't supported. App Platform static sites can't set headers,
// so this Worker moves the policy from the page's <meta> tag into a header with a
// fresh nonce and puts that nonce on every <script>, including the ones Cloudflare
// injected upstream. See issue #1 and docs/runbooks/43.md.
//
// 'strict-dynamic' is needed because the injected script builds a second inline
// script inside a hidden iframe, which can't carry a nonce. With 'strict-dynamic',
// scripts created by a nonced script are trusted. Every <script> in the page gets
// the nonce, so script-src needs no 'self' or host allowlist. Browsers that support
// 'strict-dynamic' ignore one anyway, and Firefox warns about each ignored entry.

// Keep style-src, font-src and connect-src in sync with the
// <meta http-equiv="Content-Security-Policy"> tag in app/templates/index.html.
// script-src here is nonce-only; the meta tag keeps its host allowlist because it
// has no nonce. NONCE is replaced per request.
const POLICY = [
  "default-src 'self'",
  "script-src 'nonce-NONCE' 'strict-dynamic'",
  "style-src 'self' https://cdn.jsdelivr.net https://fonts.googleapis.com",
  "font-src 'self' https://cdn.jsdelivr.net https://fonts.gstatic.com",
  "connect-src 'self' https://cdn.jsdelivr.net https://cloudflareinsights.com",
  "object-src 'none'",
].join('; ') + ';';

function makeNonce() {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return btoa(String.fromCharCode(...bytes));
}

export async function addCspNonce(response) {
  const type = response.headers.get('content-type') || '';
  if (!type.startsWith('text/html')) {
    return response;
  }

  const nonce = makeNonce();
  const rewritten = new HTMLRewriter()
    .on('meta[http-equiv="Content-Security-Policy" i]', {
      element(el) { el.remove(); },
    })
    .on('script', {
      // Every script in the page comes from the build or from Cloudflare's own
      // injection; the static site has no user input to inject markup. That's
      // the same trust Cloudflare's header-nonce feature extends.
      element(el) { el.setAttribute('nonce', nonce); },
    })
    .transform(response);

  const headers = new Headers(rewritten.headers);
  headers.set('Content-Security-Policy', POLICY.replace('NONCE', nonce));
  // A nonce must never be served twice, so the rewritten HTML isn't cacheable.
  headers.set('Cache-Control', 'private, no-store');
  headers.delete('ETag');

  return new Response(rewritten.body, {
    status: rewritten.status,
    statusText: rewritten.statusText,
    headers,
  });
}

export default {
  async fetch(request) {
    return addCspNonce(await fetch(request));
  },
};
