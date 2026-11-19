#!/bin/bash
set -e

OBSERVABILITY_BASE_URL="${OBSERVABILITY_BASE_URL:-https://raw.githubusercontent.com/CogStack/cogstack-platform/main/deployment/examples/observability}"

mkdir -p observability-simple/alloy/probers
cd observability-simple

echo "Downloading docker-compose.yml..."
curl -fsSL -o docker-compose.yml \
  "${OBSERVABILITY_BASE_URL}/simple/docker-compose.yml"

echo "Downloading probe-simple.yml into alloy/probers/..."
curl -fsSL -o alloy/probers/probe-observability.yml \
  "${OBSERVABILITY_BASE_URL}/simple/alloy/probers/probe-observability.yml"

echo "Setup complete in observability-simple/"

echo "Starting the observability stack"
docker compose up -d

 echo "Please open http://localhost/grafana in your browser"