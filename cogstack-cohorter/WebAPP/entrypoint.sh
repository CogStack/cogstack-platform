#!/bin/sh
set -e

DATA_DIR=/usr/src/app/server/data

# Ensure the writable data directory exists (may be an emptyDir or PVC mount).
mkdir -p "$DATA_DIR"

# ── Generate random patient data on first startup (random/demo mode) ──────────
if [ "${RANDOM_DATA}" = "true" ] && [ ! -f "$DATA_DIR/ptt2age.json" ]; then
    echo "[webapp] Generating random demo patient data..."
    node --max-old-space-size=32768 /usr/src/app/server/gen_random_data.js
fi

# ── Start the server ──────────────────────────────────────────────────────────
exec node --max-old-space-size=32768 server.js
