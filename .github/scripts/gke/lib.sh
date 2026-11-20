#!/usr/bin/env bash
# Shared settings for the GKE deployment test scripts. Source this file.
#
# There is no state file: everything is derived from the PR number, so any job
# can find (or clean up) the resources belonging to a PR.

: "${GCP_PROJECT_ID:?GCP_PROJECT_ID must be set}"

export GCP_ZONE="${GCP_ZONE:-europe-west2-a}"
# Cloud DNS managed zone name, and the domain it serves.
export DNS_ZONE_NAME="${DNS_ZONE_NAME:-platform}"
export BASE_DOMAIN="${BASE_DOMAIN:-platform.cogstack.dev}"

export NODE_COUNT="${NODE_COUNT:-2}"
export NODE_MACHINE_TYPE="${NODE_MACHINE_TYPE:-e2-standard-4}"
export NODE_SERVICE_ACCOUNT="gke-node@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Label carried by every cluster this test creates; the reaper selects on it.
export CLUSTER_LABEL="purpose=pr-deploy-test"

export BASIC_AUTH_USER="cogstack"
export BASIC_AUTH_SECRET="preview-basic-auth-password"

export RELEASE_NAME="cogstack"
export RELEASE_NAMESPACE="cogstack"

# Pinned so that an upstream chart release cannot break a required check.
export TRAEFIK_CHART_VERSION="42.4.1"
export CERT_MANAGER_CHART_VERSION="v1.21.3"

# Apps exposed per PR as <name>.pr-<number>.<BASE_DOMAIN>, with the path the
# smoke test requests.
export APPS="trainer:/ jupyter:/ dashboards:/ medcat:/api/health/live anoncat:/api/health/live ocr:/api/health"

# set_pr <number>: derive the per-PR names.
set_pr() {
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "PR number must be numeric, got: '$1'" >&2
    return 1
  fi
  export PR_NUMBER="$1"
  export CLUSTER_NAME="pr-${PR_NUMBER}"
  export DOMAIN="pr-${PR_NUMBER}.${BASE_DOMAIN}"
}

gc() { gcloud --project "$GCP_PROJECT_ID" --quiet "$@"; }

cluster_status() {
  gc container clusters describe "$CLUSTER_NAME" --zone "$GCP_ZONE" \
    --format='value(status)' 2>/dev/null || true
}

get_credentials() {
  gc container clusters get-credentials "$CLUSTER_NAME" --zone "$GCP_ZONE"
}

log() { echo "==> $*" >&2; }
