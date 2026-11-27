#!/usr/bin/env bash
# Deploy the minimum CogStack stack to the current kubectl context:
# HAPI FHIR, OpenSearch and NiFi.
#
# Usage, from anywhere in the repository:
#     bash deployment/scripts/minimum_deployment.sh
#
# The namespace is KUBE_NAMESPACE in deployment/env/general.env. The script is safe
# to run again: it keeps existing certificates and Secrets, and upgrades the releases.
#
# Credentials:
#     - HAPI FHIR: a random database password, generated on the first run.
#     - OpenSearch: the passwords in deployment/env/authentication.env, or the
#       OPENSEARCH_*_PASSWORD environment variables.
#     - NiFi: NIFI_SINGLE_USER_CREDENTIALS_USERNAME (default admin) and
#       NIFI_SINGLE_USER_CREDENTIALS_PASSWORD (at least 12 characters). If the
#       password is not set, a random one is generated and not shown.
#
# Not deployed: NGINX and OpenSearch Dashboards. Without NGINX nothing is published
# outside the cluster, and the NiFi NetworkPolicy admits only NGINX pods. Add it with
#     make -C deployment certs-nginx k3s-load-certs-nginx helm-install-nginx
#
# Requirements: kubectl, helm, make, openssl, jq, htpasswd and Java keytool.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
deployment_dir=$(cd -- "$script_dir/.." && pwd)
cd -- "$deployment_dir"

# shellcheck source=../env/general.env
source ./env/general.env
namespace="${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"
certs="${SECURITY_DIR:-$deployment_dir/security}/certificates"

log() { printf '\n==> %s\n' "$*"; }

secret_exists() {
    [[ -n $(kubectl -n "$namespace" get secret "$1" --ignore-not-found -o name) ]]
}

for tool in kubectl helm make openssl jq htpasswd keytool; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Missing required tool: %s\n' "$tool" >&2
        exit 1
    fi
done

log "Namespace $namespace on context $(kubectl config current-context)"
make setup-k3s-namespace

# --- HAPI FHIR ---------------------------------------------------------------
log "HAPI FHIR"
# PostgreSQL sets the password only when it first initialises its volume, so an
# existing Secret is kept.
if secret_exists hapi-fhir-db; then
    echo "secret/hapi-fhir-db already exists."
else
    kubectl -n "$namespace" create secret generic hapi-fhir-db \
        --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 24)"
fi
helm upgrade --install hapi-fhir charts/hapi-fhir -n "$namespace" \
    --wait --timeout "${HELM_TIMEOUT:-15m}"

# --- OpenSearch --------------------------------------------------------------
log "OpenSearch"
# The certificate generators refuse to overwrite, so generate only what is missing.
if [[ ! -e "$certs/root/root-ca.pem" ]]; then
    make certs-root
fi
if [[ ! -e "$certs/opensearch/opensearch-shared.crt" ]]; then
    CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-cluster.local}" \
        make certs-opensearch-shared KUBE_NAMESPACE="$namespace"
fi
make k3s-load-certs-opensearch
# Skips itself when the bootstrap Secret already exists.
make k3s-load-auth-opensearch
make helm-install-opensearch HELM_VALUES=

# --- NiFi --------------------------------------------------------------------
log "NiFi"
if secret_exists nifi-auth; then
    echo "secret/nifi-auth already exists."
else
    if [[ -z ${NIFI_SINGLE_USER_CREDENTIALS_PASSWORD:-} ]]; then
        NIFI_SINGLE_USER_CREDENTIALS_PASSWORD=$(openssl rand -hex 16)
        export NIFI_SINGLE_USER_CREDENTIALS_PASSWORD
        echo "NIFI_SINGLE_USER_CREDENTIALS_PASSWORD is not set: generated a random NiFi password."
        echo "To choose one, set it and run: make -C deployment k3s-load-auth-nifi"
    fi
    make k3s-load-auth-nifi
fi
make helm-install-nifi HELM_TIMEOUT="${HELM_TIMEOUT:-15m}"

# --- Summary -----------------------------------------------------------------
log "Deployed to namespace $namespace"
kubectl -n "$namespace" get pods
cat <<EOF

All Services are cluster-internal:
  HAPI FHIR    http://hapi-fhir:8080/fhir
  OpenSearch   http://opensearch-cluster-master:9200
  NiFi         reachable only through NGINX (see the header of this script)

To try HAPI FHIR from this machine:
  kubectl -n $namespace port-forward svc/hapi-fhir 8080:8080
  curl http://localhost:8080/fhir/metadata
EOF
