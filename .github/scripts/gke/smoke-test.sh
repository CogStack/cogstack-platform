#!/usr/bin/env bash
# Check every app answers over public HTTPS with a valid certificate, and that
# nothing is reachable without credentials.
# Usage: smoke-test.sh <pr-number>
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
set_pr "${1:?usage: smoke-test.sh <pr-number>}"

password="$(gc secrets versions access latest --secret "$BASIC_AUTH_SECRET")"
[[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::add-mask::${password}"

status() { curl -sS -o /dev/null -m 20 -w '%{http_code}' "$@" || true; }

failed=0
for app in $APPS; do
  url="https://${app%%:*}.${DOMAIN}${app#*:}"
  ok=0
  # New DNS names and certificates take a little while to be visible everywhere.
  for _ in $(seq 1 30); do
    anon="$(status "$url")"
    authed="$(status -L -u "${BASIC_AUTH_USER}:${password}" "$url")"
    if [[ "$anon" == "401" && "$authed" =~ ^2 ]]; then
      ok=1
      break
    fi
    sleep 10
  done
  if [[ "$ok" == 1 ]]; then
    echo "PASS $url (anonymous: $anon, authenticated: $authed)"
  else
    echo "FAIL $url (anonymous: $anon, want 401; authenticated: $authed, want 2xx)"
    failed=1
  fi
done
exit "$failed"
