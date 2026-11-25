# CogStack NiFi Helm chart

Deploys the CogStack Apache NiFi image with a StatefulSet, headless and web
Services, a TLS configuration ConfigMap, and persistent storage for configuration
and NiFi repositories. Application sources and the Dockerfile live in
`apps/nifi/`.

## Prerequisites

Prepare these resources in the release namespace before installing:

| Resource | Default name | Required contents |
| --- | --- | --- |
| ConfigMap | `nifi-env` | NiFi runtime environment settings for the deployment. |
| Secret | `nifi-auth` | Apache startup environment variables for login credentials, TLS passwords, the sensitive-properties key and the matching initial admin identity. |
| Secret | `cogstack-root-ca` | `ca.crt` and `truststore.jks`; the public CA and shared truststore. |
| Secret | `nifi-tls` | `nifi-keystore.jks`; the NiFi node certificate and private key. |

Set `certificates.rootCASecret` and `certificates.existingSecret` to use different
certificate Secret names. The environment ConfigMap and authentication Secret
names are currently fixed in the workload template.

The chart references these resources; it does not read host environment files or
create authentication or certificate Secrets. Keep private CA signing material
outside the pod. The namespace also needs a StorageClass or suitable
pre-provisioned persistent volumes for the six per-replica claims.

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

For local access:

```bash
kubectl -n cogstack port-forward svc/cogstack-nifi 8443:8443
```

Open `https://localhost:8443/nifi/` using the deployment's trusted CA and
credentials.

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
and readiness probes call its `/opt/nifi/scripts/cogstack-healthcheck.sh`
with the projected public CA.

## Environment-based values

Run `make -C deployment helm-values-nifi` to render `values.env.yaml` using
`deployment/env/nifi.env`. Set `NIFI_K3S_WHITELIST` to comma-separated names
from `kubectl get nodes` to populate `allowedNodes`. An empty list allows any
otherwise eligible node.

## Resource names

The `cogstack-nifi` StatefulSet uses `cogstack-nifi-headless` for pod DNS.
Clients connect to the `cogstack-nifi` ClusterIP Service. Use separate namespaces
for independent deployments. Increasing `replicaCount` requires NiFi cluster
configuration, node identities and certificates in the supplied runtime inputs.

Upgrades from the previous Service names require recreating the StatefulSet and
the old `cogstack-nifi` headless Service. Keep the existing PVCs for the recreated
StatefulSet.
