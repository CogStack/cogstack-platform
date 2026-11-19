#!/usr/bin/env bash
# One-off (and re-runnable) setup of the Google Cloud project used by the GKE
# deployment test. Run it by hand as a project owner; CI never runs this.
#
# Usage: setup-gcp.sh <owner/repo> [<owner/repo> ...]
#
# The repositories listed are the ONLY ones whose GitHub Actions runs may
# authenticate to the project. Re-running with a different list replaces the
# old one, which is how the test is moved between a fork and the main repo.
#
# Environment:
#   GCP_PROJECT_ID       project to create or reuse   (default cogstack-platform-ci)
#   GCP_ORG_ID           organisation, needed only when the project is created
#   GCP_BILLING_ACCOUNT  billing account, needed only when the project is created
#   BASE_DOMAIN          domain delegated to the project (default platform.cogstack.dev)
#   DNS_ZONE_NAME        Cloud DNS zone name              (default platform)
set -euo pipefail

[[ $# -ge 1 ]] || { sed -n '2,17p' "$0"; exit 1; }

PROJECT_ID="${GCP_PROJECT_ID:-cogstack-platform-ci}"
BASE_DOMAIN="${BASE_DOMAIN:-platform.cogstack.dev}"
DNS_ZONE_NAME="${DNS_ZONE_NAME:-platform}"
POOL="github"
PROVIDER="github"
CI_SA="gha-deploy-test@${PROJECT_ID}.iam.gserviceaccount.com"
NODE_SA="gke-node@${PROJECT_ID}.iam.gserviceaccount.com"
SECRET="preview-basic-auth-password"

gc() { gcloud --project "$PROJECT_ID" --quiet "$@"; }
log() { echo "==> $*" >&2; }

# Repositories are matched on their numeric ID, which survives renames.
ids=()
for repo in "$@"; do
  ids+=("'$(gh api "repos/${repo}" --jq .id)'")
done
condition="assertion.repository_id in [$(IFS=,; echo "${ids[*]}")]"

if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
  log "Creating project $PROJECT_ID"
  gcloud projects create "$PROJECT_ID" --organization "${GCP_ORG_ID:?GCP_ORG_ID is needed to create the project}"
  # gcloud calls the billing API on a quota shared with all gcloud users, which
  # is often exhausted for a minute at a time.
  linked=""
  for _ in 1 2 3 4 5 6 7 8; do
    if gcloud billing projects link "$PROJECT_ID" \
      --billing-account "${GCP_BILLING_ACCOUNT:?GCP_BILLING_ACCOUNT is needed to create the project}" >/dev/null 2>&1; then
      linked=1
      break
    fi
    sleep 15
  done
  [[ -n "$linked" ]] || {
    echo "Could not link billing. Link it by hand, then re-run: gcloud billing projects link $PROJECT_ID --billing-account $GCP_BILLING_ACCOUNT" >&2
    exit 1
  }
fi
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"

log "Enabling APIs"
gc services enable container.googleapis.com compute.googleapis.com dns.googleapis.com \
  iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  secretmanager.googleapis.com cloudresourcemanager.googleapis.com

log "DNS zone for $BASE_DOMAIN"
gc dns managed-zones describe "$DNS_ZONE_NAME" >/dev/null 2>&1 ||
  gc dns managed-zones create "$DNS_ZONE_NAME" --dns-name "${BASE_DOMAIN}." \
    --description "PR deployment test environments"

log "Service accounts"
for sa in "gha-deploy-test:GitHub Actions deployment test" "gke-node:GKE node service account"; do
  gc iam service-accounts describe "${sa%%:*}@${PROJECT_ID}.iam.gserviceaccount.com" >/dev/null 2>&1 ||
    gc iam service-accounts create "${sa%%:*}" --display-name "${sa#*:}"
done

grant() { gc projects add-iam-policy-binding "$PROJECT_ID" --member "$1" --role "$2" --condition None >/dev/null; }

grant "serviceAccount:${NODE_SA}" roles/container.defaultNodeServiceAccount
# The CI identity: manage clusters, DNS records and leftover disks in this project only.
grant "serviceAccount:${CI_SA}" roles/container.admin
grant "serviceAccount:${CI_SA}" roles/dns.admin
grant "serviceAccount:${CI_SA}" roles/compute.storageAdmin
gc iam service-accounts add-iam-policy-binding "$NODE_SA" \
  --member "serviceAccount:${CI_SA}" --role roles/iam.serviceAccountUser >/dev/null

log "GitHub OIDC: allowing $*"
gc iam workload-identity-pools describe "$POOL" --location global >/dev/null 2>&1 ||
  gc iam workload-identity-pools create "$POOL" --location global --display-name "GitHub Actions"
provider_args=(--location global --workload-identity-pool "$POOL"
  --attribute-mapping "google.subject=assertion.sub,attribute.repository_id=assertion.repository_id,attribute.repository=assertion.repository"
  --attribute-condition "$condition")
if gc iam workload-identity-pools providers describe "$PROVIDER" --location global \
  --workload-identity-pool "$POOL" >/dev/null 2>&1; then
  gc iam workload-identity-pools providers update-oidc "$PROVIDER" "${provider_args[@]}" >/dev/null
else
  gc iam workload-identity-pools providers create-oidc "$PROVIDER" "${provider_args[@]}" \
    --issuer-uri https://token.actions.githubusercontent.com >/dev/null
fi
# The pool is used for nothing else, and the provider condition above decides who gets in.
gc iam service-accounts add-iam-policy-binding "$CI_SA" --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/*" >/dev/null

log "Basic auth password"
if ! gc secrets describe "$SECRET" >/dev/null 2>&1; then
  gc secrets create "$SECRET" --replication-policy automatic >/dev/null
  openssl rand -hex 16 | tr -d '\n' | gc secrets versions add "$SECRET" --data-file=- >/dev/null
fi
gc secrets add-iam-policy-binding "$SECRET" --member "serviceAccount:${CI_SA}" \
  --role roles/secretmanager.secretAccessor >/dev/null

# cert-manager in every PR cluster proves domain ownership by writing DNS records.
# The Kubernetes identity pool only exists once the project has had a cluster.
log "cert-manager DNS access"
grant "principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/cert-manager/sa/cert-manager" \
  roles/dns.admin ||
  echo "WARNING: could not grant cert-manager DNS access yet. Re-run this script after the first cluster has been created." >&2

provider_name="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}/providers/${PROVIDER}"
cat <<EOF

Done.

1. Delegate ${BASE_DOMAIN} to this project (once): in the parent DNS zone,
   create an NS record for ${BASE_DOMAIN} with these values:
$(gc dns managed-zones describe "$DNS_ZONE_NAME" --format='value(nameServers)' | tr ';' '\n' | sed 's/^/     /')

2. Set these variables on each repository that should run the test:
$(for repo in "$@"; do
  echo "     gh variable set GCP_PROJECT_ID -R ${repo} -b ${PROJECT_ID}"
  echo "     gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER -R ${repo} -b ${provider_name}"
  echo "     gh variable set GCP_SERVICE_ACCOUNT -R ${repo} -b ${CI_SA}"
done)

3. Password for the PR environments (user "cogstack"):
     gcloud secrets versions access latest --secret ${SECRET} --project ${PROJECT_ID}
EOF
