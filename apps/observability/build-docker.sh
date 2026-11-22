#!/bin/sh
set -e

docker build -t cogstacksystems/observability-prometheus:latest -f prometheus/Dockerfile.prometheus ./prometheus

docker build -t cogstacksystems/observability-blackbox-exporter:latest -f prometheus/Dockerfile.blackbox ./prometheus

docker build -t cogstacksystems/observability-grafana:latest -f grafana/Dockerfile ./grafana

docker build -t cogstacksystems/observability-alloy:latest -f grafana-alloy/Dockerfile ./grafana-alloy
