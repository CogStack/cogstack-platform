# CogStack deployment

## On-premises setup

Configure the host and credentials below, then run these commands from the
repository root on the first server. Replace `cogstack.example.org` with the
hostname or IP address clients use to reach NGINX.

```bash
make -C deployment setup-all
NGINX_TLS_NAMES=cogstack.example.org make -C deployment certs-k3s
make -C deployment helm-install-all
```

`setup-all` installs the host tools, starts K3s, creates the namespace, and
verifies access. `certs-k3s` creates a fresh CA, NGINX certificate, and
OpenSearch transport certificate. Once those files exist, use `helm-install-all`
to prepare and install or upgrade NiFi, NGINX, OpenSearch, and Dashboards.

## Prerequisites

- Use Debian, Ubuntu, or RHEL with systemd, network access, Bash, GNU Make,
  `sudo`, and a full repository checkout. For multiple servers, use the
  [SSH cluster setup guide](scripts/README.md#set-up-a-cluster-over-ssh).
- Point `KUBECONFIG` at the intended K3s cluster. On a fresh host, run
  `export KUBECONFIG="$HOME/.kube/config"` before `setup-all`. Set
  `KUBE_NAMESPACE` in `deployment/env/general.env` if you want a namespace other
  than `cogstack`. [Kubeconfig setup](scripts/README.md#kubectl-access)
- When using K3s ServiceLB, add `traefik` to the `disable` list in
  `/etc/rancher/k3s/config.yaml` on each server before setup. This frees TCP port
  `443` for NGINX. Use a cluster that enforces NetworkPolicy and can provision
  the NiFi and OpenSearch persistent volumes. [Helm chart settings](charts/README.md)
- Install `htpasswd` for OpenSearch (`apache2-utils` on Debian or Ubuntu,
  `httpd-tools` on RHEL). Put the NiFi and OpenSearch passwords in a private
  copy of `deployment/env/authentication.env` and export its absolute path as
  `NIFI_AUTH_FILE` and `OPENSEARCH_AUTH_FILE`. Set `OPENSEARCH_ANALYST_PASSWORD`
  for the `cogstack_user` login in Dashboards.
- Set the store passwords in `deployment/env/certificates.env` and populate the
  NiFi environment file used to render Helm values. [NiFi environment](charts/README.md#nifi-environment)

If fresh Docker setup reports a permissions error, sign in again, set
`KUBECONFIG`, and run `make -C deployment setup-verify`.

## Verify and access the applications

Replace `cogstack` with your `KUBE_NAMESPACE` if you changed it.

```bash
helm list -n cogstack
kubectl -n cogstack get pods,pvc,svc
```

Check that the four releases are deployed, the pods are ready, and the PVCs
are bound. Point your DNS name at the external address of `cogstack-nginx` and
trust `deployment/security/certificates/root/root-ca.pem` on client machines.
Use HTTPS at `/nifi/`, `/opensearch/`, or `/dashboards/`.
