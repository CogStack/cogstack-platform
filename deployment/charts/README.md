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

## Helm charts

The shared chart workflow discovers `deployment/charts/*/Chart.yaml` for
validation and packaging. Release-please registers published charts by directory.
Use `make -C deployment helm-values-all` to render the environment-based Helm
values for OpenSearch and Dashboards.
