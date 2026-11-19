FROM traefik:v3.7.19

CMD [ \
    "--api.insecure=true", \
    "--providers.docker", \
    "--providers.docker.exposedbydefault=false", \
    "--accesslog=true", \
    "--accesslog.fields.headers.names.User-Agent=keep", \
    "--metrics.prometheus=true", \
    "--providers.file.directory=/etc/traefik/config", \
    "--providers.file.watch=true" \
]