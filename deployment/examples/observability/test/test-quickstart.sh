#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for example in simple full; do
    (
        cd "$SCRIPT_DIR/../$example"
        trap 'docker compose down' EXIT
        if [ "$example" = simple ]; then
            bash ./quickstart.sh
            cd observability-simple
        else
            bash ./full-quickstart.sh
            cd cogstack-observability
        fi
        if ! python -u "$SCRIPT_DIR/health-check.py"; then
            docker compose ps --all
            docker compose logs --no-color --tail=100
            exit 1
        fi
    )
done
