#!/usr/bin/env bash
# A served Cistergraphia answers as itself: run against any base URL, a
# container on this machine or the Cloud Run service just deployed
# (docs/serving.md). Exits non-zero at the first page that does not.
#
#   deploy/smoke.sh http://127.0.0.1:8080
#   deploy/smoke.sh https://cistergraphia-xxxx-ew.a.run.app
set -euo pipefail

base="${1:?usage: deploy/smoke.sh BASE_URL}"
base="${base%/}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Waits for /up (a container starting, a service waking): up to 60 s
started=$(date +%s)
until [[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$base/up")" == "200" ]]; do
  if (( $(date +%s) - started > 60 )); then
    echo "FAIL $base/up did not answer within 60 s" >&2
    exit 1
  fi
  sleep 1
done
echo "ok   /up answers after $(( $(date +%s) - started )) s"

check() { # label, expected status, grep pattern in the body, curl args...
  local label="$1" status="$2" pattern="$3"
  shift 3
  local code
  code=$(curl -s -o "$tmp/body" -D "$tmp/headers" -w '%{http_code}' --max-time 30 "$@")
  if [[ "$code" != "$status" ]]; then
    echo "FAIL $label: HTTP $code, expected $status" >&2
    exit 1
  fi
  if ! grep -q -- "$pattern" "$tmp/body"; then
    echo "FAIL $label: the body does not contain '$pattern'" >&2
    exit 1
  fi
  echo "ok   $label"
}

check "/ is Inscribe" 200 'action="/generate"' "$base/"
check "/decode is Read" 200 'action="/decode"' "$base/decode"
check "/chapter is the day's chapter" 200 'data-chapter=' "$base/chapter"
check "/about" 200 'About' "$base/about"
check "a plate is inscribed" 200 '<svg' --data-urlencode 'message=Ora et labora' "$base/generate"
grep -qi '^cache-control: .*no-store' "$tmp/headers" || { echo "FAIL the plate's page is cacheable" >&2; exit 1; }
grep -qi '^content-security-policy:' "$tmp/headers" || { echo "FAIL no Content-Security-Policy" >&2; exit 1; }
echo "ok   the plate's page is not cached and carries the CSP"
check "a sealed plate is inscribed" 200 '<svg' --data-urlencode 'message=Ora et labora' \
  --data-urlencode 'mode=secret' --data-urlencode 'passphrase=abbey of molesme' "$base/generate"
check "a refusal says why" 413 'limited to' --data-urlencode "message=$(head -c 600 /dev/zero | tr '\0' 'a')" "$base/generate"
check "a page not in the index" 404 'Erratum' "$base/nowhere"
check "static files are served and cacheable" 200 'plate' "$base/css/app.css"
grep -qi '^cache-control: .*max-age' "$tmp/headers" || { echo "FAIL the stylesheet is not cacheable" >&2; exit 1; }
echo "ok   the stylesheet is cacheable"
echo "All pages answer at $base"
