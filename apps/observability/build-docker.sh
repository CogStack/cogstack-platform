#!/bin/sh
set -e
cd "$(dirname "$0")"

docker build -t cogstacksystems/observability-prometheus:latest -f prometheus/Dockerfile.prometheus ./prometheus

docker build -t cogstacksystems/observability-grafana:latest -f grafana/Dockerfile ./grafana

docker build -t cogstacksystems/observability-alloy:latest -f grafana-alloy/Dockerfile ./grafana-alloy
