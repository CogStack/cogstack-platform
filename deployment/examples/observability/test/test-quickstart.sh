#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Starting deployment test..."

# Run the simple quickstart script
echo "📦 Running quickstart..."
cd ${SCRIPT_DIR}/../simple/
bash ./quickstart.sh

# Run the health check
echo "🔍 Running health check..."
python -u ../test/health-check.py

# Check if health check was successful
if [ $? -eq 0 ]; then
    echo "✅ Success! All services are running for Simple Quickstart."
    docker compose down
    exit 0
else
    echo "❌ Health check failed for simple quickstart."
    exit 1
fi


# Run the quickstart script
echo "📦 Running full quickstart..."
cd ${SCRIPT_DIR}/../full/
bash ./full-quickstart.sh

# Run the health check
echo "🔍 Running health check..."
python -u ../test/health-check.py

# Check if health check was successful
if [ $? -eq 0 ]; then
    echo "✅ Success! All services are running for Full Quickstart."
    docker compose down
    exit 0
else
    echo "❌ Health check failed for full quickstart."
    exit 1
fi

