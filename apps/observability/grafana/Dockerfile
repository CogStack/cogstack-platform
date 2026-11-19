FROM grafana/grafana-enterprise

LABEL traefik.enable="true" \
    traefik.http.routers.grafana-path-router.rule="PathPrefix(`/grafana`)" \
    traefik.http.middlewares.grafana-stripprefix.stripprefix.prefixes="/grafana" \
    traefik.http.routers.grafana-path-router.middlewares="grafana-stripprefix@docker"

RUN mkdir -p /etc/grafana/provisioning/dashboards/site

COPY ./provisioning /etc/grafana/provisioning

ENV GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/provisioning/dashboards/default/cogstack/cogstack-availability.json \
    GF_USERS_ALLOW_SIGN_UP=false \
    GF_SERVER_ROOT_URL="%(protocol)s://%(domain)s:%(http_port)s/grafana" \
    ALERTING_PAUSE_AVAILABILITY_5M=true \
    ALERTING_PAUSE_AVAILABILITY_6H=true \
    ALERTING_PAUSE_BURN_RATE=true \
    ALERTING_DEFAULT_CONTACT=Slack \
    SLACK_WEBHOOK_URL=http://localhost:3000/missing-SLACK_WEBHOOK_URL-env-var \
    PROMETHEUS_URL=http://cogstack-observability-prometheus-1:9090/prometheus