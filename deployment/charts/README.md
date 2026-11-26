# Kubernetes deployments

## NiFi and NGINX

Set `KUBE_NAMESPACE` in `deployment/env/general.env`. For a new TLS bundle,
run `make -C deployment certs` from the repository root. Load the certificates
and NiFi credentials before applying the manifests.

```bash
make -C deployment setup-k3s-namespace
make -C deployment k3s-load-certs-root-ca k3s-load-certs-nifi k3s-load-certs-nginx
make -C deployment k3s-load-auth-nifi
make -C deployment k3s-install-nifi-stack
```

The install target loads `nifi-env` and `nginx-env`, applies the
[NiFi](nifi/rendered.yaml) and [NGINX](nginx/rendered.yaml) manifests, and waits
for rollout. Set `NIFI_WEB_PROXY_HOST` in `deployment/env/nifi.env` or in the
shell when the file is absent. Use `K3S_TIMEOUT` to change the rollout timeout.

NiFi needs a StorageClass or suitable pre-provisioned volumes. Its configuration
and repository PVCs are retained when using `make -C deployment k3s-uninstall-nifi-stack`.
An existing Helm release still tracks its workloads after `kubectl apply`.
Treat Helm uninstall on those releases as workload deletion.

## OCR Service

Run `make -C deployment k3s-install-ocr-service` to apply the
[OCR Service manifest](ocr-service/rendered.yaml) and wait for rollout. Set
`OCR_SERVICE_OPERATION_MODE` to `NO_OCR` in the manifest for text extraction only.

## OpenSearch and Dashboards

Set `KUBE_NAMESPACE` in `deployment/env/general.env` and
`OPENSEARCH_KIBANA_PASSWORD` in the shell or `deployment/env/authentication.env`.
For a new certificate bundle, run `make -C deployment certs-all` from the
repository root.

```bash
make -C deployment setup-k3s-namespace
make -C deployment k3s-load-certs-opensearch k3s-load-certs-opensearch-dashboards
make -C deployment k3s-load-auth-opensearch-dashboards
make -C deployment k3s-install-opensearch-stack
```

Load the `dashboards-auth` Secret before the first bootstrap so OpenSearch and
Dashboards share the `kibanaserver` password. Set the optional
`OPENSEARCH_NIFI_PASSWORD`, `OPENSEARCH_PIPELINE_PASSWORD`, and
`OPENSEARCH_ANALYST_PASSWORD` to create those accounts during bootstrap. Set
`BOOTSTRAP_OPENSEARCH_SECURITY=0` to skip bootstrap.

The stack applies the [OpenSearch](opensearch/rendered.yaml) and
[Dashboards](opensearch-dashboards/rendered.yaml) manifests. Set replica counts
and resources in those files, and choose the OpenSearch claim size and storage
class before the first install. Restart the workload after changing its mounted
ConfigMap. OpenSearch and Dashboards serve HTTPS on ports `9200` and `5601`.
`make -C deployment k3s-uninstall-opensearch-stack` deletes the workloads and
retains the OpenSearch PVCs.

## Helm charts

The shared chart workflow discovers `deployment/charts/*/Chart.yaml` for
validation and packaging. Release-please registers published charts by directory.
