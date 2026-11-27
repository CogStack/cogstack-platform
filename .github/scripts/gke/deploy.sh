#!/usr/bin/env bash
# Deploy this checkout's minimum stack (HAPI FHIR, OpenSearch, NiFi) to the PR's
# cluster, behind HTTPS, with deployment/scripts/minimum_deployment.sh.
# Safe to re-run: a later push to the PR applies the manifests again.
# Usage: deploy.sh <pr-number>   (run cluster-up.sh first)
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
set_pr "${1:?usage: deploy.sh <pr-number>}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
WORK="$(mktemp -d)"

log "Installing cert-manager $CERT_MANAGER_CHART_VERSION"
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version "$CERT_MANAGER_CHART_VERSION" \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  --wait --timeout 10m

log "Installing Traefik $TRAEFIK_CHART_VERSION"
helm upgrade --install traefik oci://ghcr.io/traefik/helm/traefik \
  --version "$TRAEFIK_CHART_VERSION" \
  --namespace traefik --create-namespace \
  -f traefik-values.yaml \
  --wait --timeout 10m

log "Waiting for the load balancer address"
LB_IP=""
for _ in $(seq 1 60); do
  LB_IP="$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
  [[ -n "$LB_IP" ]] && break
  sleep 5
done
[[ -n "$LB_IP" ]] || { echo "Traefik service never received an external IP" >&2; exit 1; }

log "Pointing *.${DOMAIN} at ${LB_IP}"
record="*.${DOMAIN}."
if gc dns record-sets describe "$record" --type A --zone "$DNS_ZONE_NAME" >/dev/null 2>&1; then
  gc dns record-sets update "$record" --type A --zone "$DNS_ZONE_NAME" --ttl 60 --rrdatas "$LB_IP" >/dev/null
else
  gc dns record-sets create "$record" --type A --zone "$DNS_ZONE_NAME" --ttl 60 --rrdatas "$LB_IP" >/dev/null
fi

log "Configuring basic auth"
password="$(gc secrets versions access latest --secret "$BASIC_AUTH_SECRET")"
[[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::add-mask::${password}"
kubectl -n traefik create secret generic basic-auth-users \
  --from-literal=users="${BASIC_AUTH_USER}:$(openssl passwd -apr1 "$password")" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Requesting the wildcard certificate for *.${DOMAIN}"
envsubst '${GCP_PROJECT_ID} ${DOMAIN}' < platform.tmpl.yaml | kubectl apply -f -
kubectl -n traefik wait --for=condition=Ready certificate/wildcard --timeout=15m

log "Deploying the minimum stack"
# The script takes its OpenSearch users from this file instead of the passwords
# committed in deployment/env/authentication.env.
printf 'OPENSEARCH_ADMIN_PASSWORD=%s\nOPENSEARCH_KIBANA_PASSWORD=%s\n' \
  "$password" "$(openssl rand -hex 16)" > "$WORK/authentication.env"
OPENSEARCH_AUTH_FILE="$WORK/authentication.env" INGRESS_DOMAIN="$DOMAIN" \
  bash "$REPO_ROOT/deployment/scripts/minimum_deployment.sh"

log "Waiting for the workloads"
for workload in $(kubectl -n "$NAMESPACE" get deployment,statefulset -o name); do
  kubectl -n "$NAMESPACE" rollout status "$workload" --timeout=20m
done
