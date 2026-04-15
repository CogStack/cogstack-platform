#!/bin/sh
set -e

DATA_DIR=/usr/src/app/server/data

# ── Step 1: extract archive if JSON data isn't already present ────────────────
if [ ! -f "$DATA_DIR/snomed_terms.json" ]; then
    if [ -f "$DATA_DIR/snomed_terms_data.tar.gz" ]; then
        echo "[webapp] Extracting SNOMED data archive..."
        tar xzvf "$DATA_DIR/snomed_terms_data.tar.gz" -C "$DATA_DIR"
    else
        echo "[webapp] ERROR: No data found at $DATA_DIR." >&2
        echo "[webapp] Mount a directory containing snomed_terms.json (and related files)" >&2
        echo "[webapp] or snomed_terms_data.tar.gz via a Docker volume:" >&2
        echo "[webapp]   -v /your/data:/usr/src/app/server/data" >&2
        exit 1
    fi
fi

# ── Step 2 (optional): generate random patient data ───────────────────────────
# Set RANDOM_DATA=true in the container environment to generate synthetic data.
if [ "${RANDOM_DATA}" = "true" ]; then
    echo "[webapp] Generating random demo patient data..."
    node --max-old-space-size=32768 /usr/src/app/server/gen_random_data.js
fi

# ── Step 3: start the server ──────────────────────────────────────────────────
exec node --max-old-space-size=32768 server.js
