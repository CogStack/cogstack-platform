#!/usr/bin/env bash
# Deploy the minimum CogStack stack to the current kubectl context:
# HAPI FHIR, OpenSearch and NiFi.
#
#     bash deployment/scripts/minimum_deployment.sh
#
# Each service is rendered with `helm template` to deployment/rendered/<service>.yaml
# and applied with `kubectl apply`. The namespace is KUBE_NAMESPACE in
# deployment/env/general.env. Safe to run again: existing Secrets are kept.
#
# The charts read four Secrets that cannot be committed, so step 1 creates any
# that are missing. OpenSearch users and their passwords come from
# deployment/env/authentication.env.
#
# Requirements: kubectl, helm, openssl, htpasswd.
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
source ./env/general.env
ns=$KUBE_NAMESPACE
mkdir -p rendered

kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -

# --- 1. Secrets ----------------------------------------------------------------
secret_missing() { ! kubectl -n "$ns" get secret "$1" >/dev/null 2>&1; }

# HAPI FHIR: PostgreSQL password.
if secret_missing hapi-fhir-db; then
    kubectl -n "$ns" create secret generic hapi-fhir-db \
        --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 24)"
fi

# NiFi: key that encrypts sensitive values in the flow.
if secret_missing nifi-auth; then
    kubectl -n "$ns" create secret generic nifi-auth \
        --from-literal=NIFI_SENSITIVE_PROPS_KEY="$(openssl rand -hex 16)"
fi

# OpenSearch: the security plugin requires TLS between nodes. One self-signed
# certificate, which every node presents and trusts, is enough. Its subject must
# match plugins.security.nodes_dn in charts/opensearch/config/opensearch.yml.
if secret_missing opensearch-node-tls; then
    tls=$(mktemp -d)
    openssl req -x509 -newkey rsa:4096 -nodes -days 1460 \
        -subj "/C=UK/ST=London/L=UK/O=cogstack/OU=cogstack/CN=opensearch-shared" \
        -keyout "$tls/node.key" -out "$tls/node.crt"
    kubectl -n "$ns" create secret generic opensearch-node-tls \
        --from-file=node.crt="$tls/node.crt" \
        --from-file=node.key="$tls/node.key" \
        --from-file=ca.crt="$tls/node.crt"
    rm -rf -- "$tls"
fi

# OpenSearch: users, roles and role mappings (opensearch-security-bootstrap).
# Does nothing when the Secret already exists.
bash scripts/security/load_opensearch_auth.sh opensearch

# --- 2. Render and apply -------------------------------------------------------
helm template hapi-fhir charts/hapi-fhir > rendered/hapi-fhir.yaml
kubectl -n "$ns" apply -f rendered/hapi-fhir.yaml

# The upstream OpenSearch chart is a dependency, downloaded into charts/opensearch/charts.
helm repo add opensearch https://opensearch-project.github.io/helm-charts/ --force-update
helm dependency build charts/opensearch
helm template opensearch charts/opensearch --skip-tests \
    --set-file 'opensearch.config.opensearch\.yml=charts/opensearch/config/opensearch.yml' \
    > rendered/opensearch.yaml
kubectl -n "$ns" apply -f rendered/opensearch.yaml

helm template cogstack-nifi charts/nifi > rendered/nifi.yaml
kubectl -n "$ns" apply -f rendered/nifi.yaml

# --- 3. Status -----------------------------------------------------------------
kubectl -n "$ns" get pods
cat <<EOF

Pods take a few minutes to become ready: kubectl -n $ns get pods -w

All Services are cluster-internal:
  HAPI FHIR    http://hapi-fhir:8080/fhir
  OpenSearch   http://opensearch-cluster-master:9200
  NiFi         http://cogstack-nifi:8080, which only NGINX pods may reach

To try HAPI FHIR from this machine:
  kubectl -n $ns port-forward svc/hapi-fhir 8080:8080
  curl http://localhost:8080/fhir/metadata
EOF
