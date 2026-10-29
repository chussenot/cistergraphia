// The front door (cloudflare.tf): every request for the domain, re-addressed
// to the Cloud Run service's own host, as it came: the method, the headers,
// the body. The domain the reader used goes in X-Forwarded-Host, so that the
// app's links (og:url) name the domain and not the run.app address.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const readerHost = url.host;
    url.host = env.ORIGIN_HOST;
    url.protocol = 'https:';
    const headers = new Headers(request.headers);
    headers.set('X-Forwarded-Host', readerHost);
    headers.set('X-Forwarded-Proto', 'https');
    return fetch(new Request(url, { method: request.method, headers, body: request.body, redirect: 'manual' }));
  },
};
