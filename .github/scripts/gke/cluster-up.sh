#!/usr/bin/env bash
# Create the GKE cluster for a PR if it does not exist yet, then fetch credentials.
# Usage: cluster-up.sh <pr-number>
set -euo pipefail
cd "$(dirname "$0")"
source ./lib.sh
set_pr "${1:?usage: cluster-up.sh <pr-number>}"

status="$(cluster_status)"
case "$status" in
  "")
    log "Creating cluster $CLUSTER_NAME in $GCP_ZONE"
    gc container clusters create "$CLUSTER_NAME" \
      --zone "$GCP_ZONE" \
      --release-channel regular \
      --num-nodes "$NODE_COUNT" \
      --machine-type "$NODE_MACHINE_TYPE" \
      --disk-type pd-balanced \
      --disk-size 50 \
      --service-account "$NODE_SERVICE_ACCOUNT" \
      --workload-pool "${GCP_PROJECT_ID}.svc.id.goog" \
      --labels "${CLUSTER_LABEL},pr=${PR_NUMBER}"
    ;;
  RUNNING | RECONCILING)
    log "Reusing existing cluster $CLUSTER_NAME ($status)"
    ;;
  *)
    echo "Cluster $CLUSTER_NAME is in state $status. Run the teardown workflow for PR $PR_NUMBER, then re-run this job." >&2
    exit 1
    ;;
esac

get_credentials
kubectl wait --for=condition=Ready nodes --all --timeout=300s
