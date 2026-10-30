// The front door (cloudflare.tf): every request for the domain, re-addressed
// to the Cloud Run service's own host, as it came: the method, the headers,
// the body. The domain the reader used goes in X-Forwarded-Host, so that the
// app's links (og:url) name the domain and not the run.app address.
//
// What the door refuses, before Cloud Run is asked:
// - a method the app has no use for (it answers GET, HEAD and POST)
// - a body larger than any plate (the app's own limit is 2 MB): Cloud Run
//   would accept 32 MB, and read it
// What it adds:
// - the key (FRONT_DOOR_KEY): the service refuses a request without it, so
//   its run.app address is no way around the rate limit
// - the edge cache for GET and HEAD, as each page's Cache-Control allows:
//   the pages are the same for every reader, and a page served from the edge
//   costs the service nothing
// What it drops: the query string of a GET, except on the chapter's pages
// (the board's rejoined=1). No other page reads one, so ?x=1, ?x=2, ... would
// only be as many cache misses, each a request the service has to answer.
const METHODS = new Set(['GET', 'HEAD', 'POST']);
const MAX_BODY = 3 * 1024 * 1024;
const QUERY_READ = /^\/chapter(\/|$)/;

export default {
  async fetch(request, env) {
    if (!METHODS.has(request.method)) {
      return new Response('Method not allowed.\n', { status: 405, headers: { allow: 'GET, HEAD, POST' } });
    }
    if (Number(request.headers.get('content-length') || 0) > MAX_BODY) {
      return new Response('The request is larger than any plate.\n', { status: 413 });
    }
    const url = new URL(request.url);
    const readerHost = url.host;
    url.host = env.ORIGIN_HOST;
    url.protocol = 'https:';
    if (request.method !== 'POST' && !QUERY_READ.test(url.pathname)) url.search = '';
    const headers = new Headers(request.headers);
    headers.set('X-Forwarded-Host', readerHost);
    headers.set('X-Forwarded-Proto', 'https');
    headers.set('X-Front-Door-Key', env.FRONT_DOOR_KEY);
    const cacheable = request.method !== 'POST';
    return fetch(new Request(url, { method: request.method, headers, body: request.body, redirect: 'manual' }),
      { cf: { cacheEverything: cacheable } });
  },
};
