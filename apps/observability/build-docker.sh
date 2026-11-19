
docker build -t cogstacksystems/cogstack-observability-prometheus:latest -f prometheus/Dockerfile.prometheus ./prometheus

docker build -t cogstacksystems/cogstack-observability-blackbox-exporter:latest -f prometheus/Dockerfile.blackbox ./prometheus

docker build -t cogstacksystems/cogstack-observability-grafana:latest -f grafana/Dockerfile ./grafana

docker build -t cogstacksystems/cogstack-observability-traefik:latest -f traefik/Dockerfile ./traefik

docker build -t cogstacksystems/cogstack-observability-alloy:latest -f grafana-alloy/Dockerfile ./grafana-alloy