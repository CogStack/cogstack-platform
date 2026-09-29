# cogstack-jupyterhub Helm Chart

This chart deploys the CogStack JupyterHub service and mirrors the current Docker Compose setup:

- loads `env/general.env` and `env/jupyter.env`
- mounts `jupyterhub_config.py`, `userlist`, and `teamlist`
- mounts TLS/cookie files used by JupyterHub
- mounts `/var/run/docker.sock` for DockerSpawner

## Install using repo env files

From the repository root:

```bash
helm upgrade --install cogstack-jupyterhub ./charts/cogstack-jupyterhub \
  --namespace cogstack --create-namespace \
  --set envFiles.useBundled=false \
  --set hubFiles.useBundled=false \
  --set securityFiles.useBundled=false \
  --set-file envFiles.jupyter=env/jupyter.env \
  --set-file envFiles.general=env/general.env \
  --set-file hubFiles.jupyterhubConfig=config/jupyterhub_config.py \
  --set-file hubFiles.userlist=config/userlist \
  --set-file hubFiles.teamlist=config/teamlist \
  --set-file securityFiles.cookieSecret=config/jupyterhub_cookie_secret \
  --set-file securityFiles.tlsKey=security/nifi.key \
  --set-file securityFiles.tlsCert=security/nifi.pem
```

## Bundled file mode

By default, the chart contains copies of current repo files under `charts/cogstack-jupyterhub/files/*`.
If you leave `*.useBundled=true`, Helm will use those bundled copies.

## Notes

- This chart keeps DockerSpawner behavior, so it mounts the host Docker socket.
- For multi-node/production Kubernetes, migrating to KubeSpawner is strongly recommended.
