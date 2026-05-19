#!/bin/sh
set -e

DATA_DIR=/usr/src/app/server/data

# Ensure the writable data directory exists (may be an emptyDir or PVC mount).
mkdir -p "$DATA_DIR"

# ── Generate random patient data on first startup (random/demo mode) ──────────
if [ "${RANDOM_DATA}" = "true" ] && \
   { [ ! -f "$DATA_DIR/ptt2age.json" ]      || \
     [ ! -f "$DATA_DIR/ptt2sex.json" ]      || \
     [ ! -f "$DATA_DIR/ptt2eth.json" ]      || \
     [ ! -f "$DATA_DIR/ptt2dod.json" ]      || \
     [ ! -f "$DATA_DIR/cui2ptt_pos.jsonl" ] || \
     [ ! -f "$DATA_DIR/cui2ptt_tsp.jsonl" ]; }; then
    echo "[webapp] Generating random demo patient data..."
    node --max-old-space-size=32768 /usr/src/app/server/gen_random_data.js
fi

# ── Inject runtime config for the React app ──────────────────────────────────
# Writes config.js into the pre-built dist folder so Express serves it
# as /config.js.
# Override any of these via OAUTH2_* env vars.
#
# Values are sanitised before being embedded in the JS string literal:
# backslashes are escaped first, then double-quotes, preventing a
# malformed env var from injecting arbitrary JavaScript.
_js_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

CONFIG_JS=/usr/src/app/client-react/dist/config.js
{
  printf 'window.__RUNTIME_CONFIG__ = {\n'
  printf '  OAUTH2_USERINFO_PATH: "%s",\n' "$(_js_escape "${OAUTH2_USERINFO_PATH:-/oauth2/userinfo}")"
  printf '  OAUTH2_LOGIN_PATH:    "%s",\n' "$(_js_escape "${OAUTH2_LOGIN_PATH:-/oauth2/sign_in}")"
  printf '  OAUTH2_LOGOUT_PATH:   "%s",\n' "$(_js_escape "${OAUTH2_LOGOUT_PATH:-/oauth2/sign_out?rd=/}")"
  printf '};\n'
} > "$CONFIG_JS"

# ── Start the server ──────────────────────────────────────────────────────────
exec node --max-old-space-size=32768 server.js
