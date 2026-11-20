#!/usr/bin/env bash
# Remove everything belonging to a PR environment. Every step tolerates
# "already gone", so a teardown that died half way can simply be re-run.
# Usage: teardown.sh <pr-number>
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ./lib.sh
set_pr "${1:?usage: teardown.sh <pr-number>}" || exit 1

status="$(cluster_status)"
if [[ -n "$status" ]]; then
  # Release cloud resources owned by Kubernetes objects first. Deleting the
  # cluster alone leaves the load balancer and the volume disks behind, billing.
  if [[ "$status" == "RUNNING" || "$status" == "RECONCILING" ]] && get_credentials; then
    log "Removing workloads, volumes and the load balancer"
    helm uninstall "$RELEASE_NAME" -n "$RELEASE_NAMESPACE" --wait --timeout 10m || true
    kubectl delete namespace "$RELEASE_NAMESPACE" --ignore-not-found --timeout=10m || true
    helm uninstall traefik -n traefik --wait --timeout 10m || true
    kubectl -n traefik delete svc --all --ignore-not-found --timeout=10m || true
  else
    log "Cluster is $status; skipping in-cluster cleanup"
  fi

  log "Deleting cluster $CLUSTER_NAME"
  gc container clusters delete "$CLUSTER_NAME" --zone "$GCP_ZONE" || {
    echo "Cluster delete failed" >&2
    exit 1
  }
else
  log "No cluster named $CLUSTER_NAME"
fi

log "Deleting DNS records for ${DOMAIN}"
gc dns record-sets list --zone "$DNS_ZONE_NAME" --format='value(name,type)' \
  --filter="name ~ \.${DOMAIN}\.\$ AND type != NS AND type != SOA" |
  while read -r name type; do
    gc dns record-sets delete "$name" --type "$type" --zone "$DNS_ZONE_NAME" >/dev/null || true
  done

log "Deleting any volume disks the cluster left behind"
gc compute disks list --format='value(name,zone.basename())' \
  --filter="labels.goog-k8s-cluster-name=${CLUSTER_NAME} AND -users:*" |
  while read -r name zone; do
    gc compute disks delete "$name" --zone "$zone" || true
  done

# Tell anyone looking at the PR that its links no longer work.
if [[ -n "${GH_TOKEN:-}" ]]; then
  ./pr-status.sh "$PR_NUMBER" removed || true
fi

log "Teardown of PR ${PR_NUMBER} complete"
