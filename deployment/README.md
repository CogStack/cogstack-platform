# CogStack deployment

## Prerequisites

- A Debian, Ubuntu or Red Hat Enterprise Linux host running systemd, with
  network access to package repositories, installer downloads and container
  registries. [K3s host requirements](https://docs.k3s.io/installation/requirements)
- A full checkout of this repository, Bash, GNU Make and `sudo` access. Sign in
  as the user who will manage the cluster. The setup scripts call `sudo` as
  needed.
- Set `KUBE_NAMESPACE` in `env/general.env`. The default is `cogstack`.
- On a fresh host, run `export KUBECONFIG="$HOME/.kube/config"` in your setup
  shell. Setup creates this file if it is absent. If you already have a
  kubeconfig, point `KUBECONFIG` to a user-readable configuration for the local
  K3s cluster. [Kubeconfig setup](scripts/README.md#kubectl-access)

If you plan to use the NGINX chart with K3s ServiceLB, reserve TCP port `443`
for NGINX. Before starting K3s, add `traefik` to the `disable` list in
`/etc/rancher/k3s/config.yaml` on each server. [K3s configuration](https://docs.k3s.io/installation/configuration#configuration-file)

```yaml
disable:
  - traefik
```

## On-premises setup

Run from the `deployment/` directory.

```bash
make setup-all
```

This installs the host utilities, Docker with Compose, K3s and Helm. It starts
the first K3s server, creates the configured namespace and checks that Docker
and Kubernetes are accessible to your user.

On a fresh Docker installation, your current shell may still lack the `docker`
group membership added during setup. If Docker verification fails with a
permissions error, sign out and back in, set `KUBECONFIG` again and run
`make setup-verify` from `deployment/`.

For multi-node setup over SSH, follow the [cluster setup guide](scripts/README.md#set-up-a-cluster-over-ssh).

## Install the applications

The Helm targets deploy NiFi, NGINX, OpenSearch and OpenSearch Dashboards.
Before installing, make sure the cluster enforces NetworkPolicy and has a
StorageClass that can provision the NiFi and OpenSearch claims. Review the CPU,
memory and storage settings for your deployment. [Helm charts](charts/README.md)

1. Install `htpasswd` for OpenSearch authentication. The package is
   `apache2-utils` on Debian and Ubuntu or `httpd-tools` on RHEL.
2. Put your NiFi login and OpenSearch passwords in a private copy of
   `env/authentication.env`. Export `NIFI_AUTH_FILE` and `OPENSEARCH_AUTH_FILE`
   with the path to that file. Use a separate OpenSearch user, such as the
   analyst configured by `OPENSEARCH_ANALYST_PASSWORD`, to sign in to Dashboards.
3. Set the certificate store passwords in `env/certificates.env`. For a new
   deployment, generate the certificates using the hostname or IP address that
   clients will use to reach NGINX. Then install the charts.

   ```bash
   NGINX_TLS_NAMES=cogstack.example.org make certs-k3s
   make helm-install-all
   ```

   If the required certificates are already in place, run `make helm-install-all`
   to reuse them. This target renders the Helm values, loads the Kubernetes
   Secrets and ConfigMaps and installs both application stacks.

## Verify and access the applications

Replace `cogstack` with your `KUBE_NAMESPACE` if you changed it.

```bash
helm list -n cogstack
kubectl -n cogstack get pods,pvc,svc
```

Check that the four releases are deployed, the pods are ready and the PVCs are
bound. If using a hostname, point it to the external address of the
`cogstack-nginx` Service. Trust the generated CA on client machines. The default
CA path is `security/certificates/root/root-ca.pem`. Use the hostname or IP from
`NGINX_TLS_NAMES` over HTTPS with `/nifi/`, `/opensearch/` or `/dashboards/`.

Run `make help` for the available deployment targets.
