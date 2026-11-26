# CogStack NiFi Helm chart

Deploys the CogStack Apache NiFi image with a StatefulSet, cluster-internal HTTP
Services, and persistent storage for configuration and NiFi repositories.
NGINX handles HTTPS and login for the UI and API. [NGINX chart](../nginx/README.md)

## Prerequisites

Run `make -C deployment k3s-load-auth-nifi` to create or update `nifi-auth` with
the NiFi flow encryption key and the NGINX `htpasswd` entry. Set
`NIFI_SINGLE_USER_CREDENTIALS_USERNAME` and `NIFI_SINGLE_USER_CREDENTIALS_PASSWORD`
in the environment or `deployment/env/authentication.env`. The loader uses
OpenSSL and prompts for a deployment password if needed. It preserves the
existing `NIFI_SENSITIVE_PROPS_KEY` when upgrading.

The namespace needs a StorageClass or persistent volumes for the six claims per
replica. NiFi grants full access in HTTP mode. Use a cluster that enforces
NetworkPolicy so the chart can restrict access to the NGINX pods in the same
namespace.

## Render and install

Run from the platform repository root:

```bash
helm lint ./deployment/charts/nifi
helm template cogstack-nifi ./deployment/charts/nifi --namespace cogstack
helm upgrade --install cogstack-nifi ./deployment/charts/nifi \
  --namespace cogstack --create-namespace
```

Pass deployment overrides with `-f /path/to/nifi-values.yaml`. The default image
is `cogstacksystems/nifi:latest`; set `image.tag` to the image release
required by the deployment.

Use the NGINX `/nifi/` and `/nifi-api/` routes with HTTP Basic authentication.

## Persistent configuration and data

The chart creates one claim per replica for each of:

- `flowfile_repository`
- `content_repository`
- `provenance_repository`
- `database_repository`
- `state`
- `conf`

The initialization container seeds an empty configuration claim from
`$NIFI_HOME/conf` in the image, validates the required files and records a
`.nifi-bootstrap-complete` marker. Existing verified configuration is preserved
on upgrades. An interrupted initialization or an unverified non-empty claim
requires operator recovery before NiFi starts.

Claims are retained when the StatefulSet is deleted or scaled down. Configure
storage with `persistence.storageClassName`, `persistence.accessModes` and
`persistence.volumes.<name>`. A `null` StorageClass uses the cluster default;
an empty string selects no StorageClass. Each claim can override the global
StorageClass and access modes. Existing StatefulSet claim templates have
Kubernetes immutability constraints; plan storage changes and backups separately.

Drivers, schemas and Python processors are bundled by the NiFi image. Startup
and readiness probes use NiFi's loopback HTTP endpoint.

## Environment-based values

Run `make -C deployment helm-values-nifi` to render `values.env.yaml` using
`deployment/env/nifi.env`. Set `NIFI_K3S_WHITELIST` to comma-separated names
from `kubectl get nodes` to populate `allowedNodes`. An empty list allows any
otherwise eligible node.

## Resource names

The `cogstack-nifi` StatefulSet uses `cogstack-nifi-headless` for pod DNS. NGINX
connects to the `cogstack-nifi` ClusterIP Service on port `8080`. Use separate
namespaces for independent deployments.

Upgrades from the previous Service names require recreating the StatefulSet and
the old `cogstack-nifi` headless Service. Keep the existing PVCs for the recreated
StatefulSet.
