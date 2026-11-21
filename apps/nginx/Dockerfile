FROM nginx:1.31.9@sha256:84f7876d21d154885f99554d7ae325d8c2213f9169726ea7ab60642f2573a787

ARG NGINX_UID=1000
ARG NGINX_GID=1000

COPY nginx.conf /etc/nginx/nginx.conf
COPY profiles/ /etc/nginx/templates/
COPY LICENSE /usr/share/doc/cogstack-nginx/LICENSE

ENV HOME=/tmp \
    NGINX_ENVSUBST_TEMPLATE_DIR=/etc/nginx/templates/nifi \
    NGINX_ENVSUBST_OUTPUT_DIR=/tmp \
    NGINX_ENVSUBST_FILTER="^(NGINX_|NIFI_|MEDCAT_)" \
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    NGINX_HEALTH_PORT=8080 \
    NIFI_UPSTREAM_HOST=nifi \
    NIFI_UPSTREAM_PORT=8443 \
    NIFI_UPSTREAM_TLS_NAME=nifi \
    NIFI_INTERNAL_PORT_NGINX=8443 \
    NIFI_WEB_PROXY_PORT=8443 \
    NGINX_NIFI_SERVER_NAME=_ \
    NGINX_PROXY_CONTEXT_PATH="" \
    NGINX_PROXY_SCHEME=https \
    NGINX_TLS_CERTIFICATE=/certificates/nifi/nifi.pem \
    NGINX_TLS_CERTIFICATE_KEY=/certificates/nifi/nifi.key \
    NGINX_UPSTREAM_CA=/certificates/root/root-ca.pem \
    MEDCAT_LISTEN_PORT=8001 \
    MEDCAT_SERVER_NAME=_ \
    MEDCAT_UPSTREAM_HOST=127.0.0.1 \
    MEDCAT_UPSTREAM_PORT=8000 \
    MEDCAT_SOLR_HOST=solr \
    MEDCAT_SOLR_PORT=8983 \
    MEDCAT_STATIC_ROOT=/home/api/static \
    MEDCAT_MEDIA_ROOT=/home/api/media

USER ${NGINX_UID}:${NGINX_GID}
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["sh", "-c", "exec curl -fsS --noproxy '*' --max-time 5 -o /dev/null \"http://127.0.0.1:${NGINX_HEALTH_PORT}/healthz/ready\""]
