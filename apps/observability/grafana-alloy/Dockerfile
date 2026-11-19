FROM grafana/alloy:latest

LABEL traefik.enable="true" \
    traefik.http.routers.alloy.rule="PathPrefix(`/alloy`)" 

EXPOSE 12345

RUN mkdir -p /etc/alloy/probers

COPY ./defaults /etc/alloy

CMD [ \
    "run", \
    "--server.http.listen-addr=0.0.0.0:12345", \
    "--storage.path=/var/lib/alloy/data", \
    "--server.http.ui-path-prefix=/alloy", \
    "/etc/alloy" \
    ] 

ENV PROMETHEUS_URL=http://cogstack-observability-prometheus-1:9090/prometheus

