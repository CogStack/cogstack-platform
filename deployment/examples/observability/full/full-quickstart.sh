#!/bin/bash
set -e
OBSERVABILITY_BASE_URL="${OBSERVABILITY_BASE_URL:-https://raw.githubusercontent.com/CogStack/cogstack-platform/main/deployment/examples/observability}"

download_to() {
  local path="$1"
  local url="${OBSERVABILITY_BASE_URL}/full/${path}"

  echo "Downloading ${path} from ${url}"
  mkdir -p "$(dirname "$path")"
  curl -fsSL -o "$path" "$url"
}

mkdir -p cogstack-observability/alloy/probers
mkdir -p cogstack-observability/prometheus/scrape-configs/probers
mkdir -p cogstack-observability/prometheus/scrape-configs/exporters
mkdir -p cogstack-observability/prometheus/scrape-configs/recording-rules
cd cogstack-observability

download_to docker-compose.yml
download_to exporters.docker-compose.yml
download_to exporters.elastic.docker-compose.yml

download_to alloy/probers/probe-observability.yml
download_to alloy/probers/probe-external.yml
download_to prometheus/scrape-configs/exporters/exporters.yml
download_to prometheus/scrape-configs/recording-rules/slo.yml

echo "Setup complete in cogstack-observability/"

echo "Starting the observability stack"

docker compose up -d --remove-orphans

echo "Please open http://localhost/grafana in your browser"
