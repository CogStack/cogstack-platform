#!/bin/sh
set -e

DATA_DIR=/usr/src/app/server/data
BUNDLED_ARCHIVE=/usr/src/app/server/data-bundled/snomed_terms_data.tar.gz

# ── Step 1: extract bundled SNOMED data if not already present ────────────────
if [ ! -f "$DATA_DIR/snomed_terms.json" ]; then
    echo "[webapp] Extracting bundled SNOMED data..."
    tar xzvf "$BUNDLED_ARCHIVE" -C "$DATA_DIR"
fi

# ── Step 2 (optional): generate random patient data ───────────────────────────
# Runs only on first startup — skipped if patient data files already exist.
# Set RANDOM_DATA=false and supply real MIMIC-IV shaped data via volume mount.
if [ "${RANDOM_DATA}" = "true" ] && [ ! -f "$DATA_DIR/ptt2age.json" ]; then
    echo "[webapp] Generating random demo patient data..."
    node --max-old-space-size=32768 /usr/src/app/server/gen_random_data.js
fi

# ── Step 3: start the server ──────────────────────────────────────────────────
exec node --max-old-space-size=32768 server.js
