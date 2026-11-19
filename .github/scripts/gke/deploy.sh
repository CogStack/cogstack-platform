#!/usr/bin/env bash
# Deploy this checkout of cogstack-ce-helm to the PR's cluster, behind HTTPS.
# Safe to re-run: a later push to the PR upgrades the existing release.
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

log "Deploying cogstack-ce-helm"
envsubst '${DOMAIN}' < values.tmpl.yaml > "$WORK/values.yaml"
(cd "$REPO_ROOT/deployment/charts" && "$REPO_ROOT/.github/scripts/helm-recursive-dependency-update.py")

# A release left failed or half-applied by an earlier run blocks upgrades; start it clean.
release_status="$(helm status "$RELEASE_NAME" -n "$RELEASE_NAMESPACE" -o json 2>/dev/null | jq -r '.info.status' || true)"
if [[ -n "$release_status" && "$release_status" != "deployed" ]]; then
  log "Release is '$release_status'; uninstalling before reinstall"
  helm uninstall "$RELEASE_NAME" -n "$RELEASE_NAMESPACE" --wait --timeout 10m
fi

helm upgrade --install "$RELEASE_NAME" "$REPO_ROOT/deployment/charts/cogstack-ce-helm" \
  --namespace "$RELEASE_NAMESPACE" --create-namespace \
  -f "$WORK/values.yaml" \
  --wait --timeout 30m

log "Running helm tests"
helm test "$RELEASE_NAME" -n "$RELEASE_NAMESPACE" --logs --timeout 15m
