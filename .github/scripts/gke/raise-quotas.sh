#!/usr/bin/env bash
# Ask Google to double the quotas that limit how many PR environments the GKE
# deployment test can run at once. Run it by hand as a project owner; CI never
# runs this.
#
# Usage: raise-quotas.sh
#
# Each quota's current limit is read from the project and a request is filed for
# twice that, so every run doubles again. An increase is a request: Google
# grants it at once or reviews it first. See what happened with:
#
#     gcloud quotas preferences list --project <project>
#
# Environment:
#   GCP_PROJECT_ID        project to change            (default cogstack-platform-ci)
#   GCP_ZONE              zone the PR clusters run in  (default europe-west2-a)
#   QUOTA_CONTACT_EMAIL   address Google writes to about the request; Google
#                         refuses an increase without one (default
#                         andrew@cogstack.org). Its Google account must be
#                         allowed to change quotas on the project.
#   DRY_RUN=1             validate the requests without filing them
#
# Commands: https://docs.cloud.google.com/docs/quotas/gcloud-cli-examples
# Requirements: gcloud, jq.
set -euo pipefail

QUOTA_CONTACT_EMAIL="${QUOTA_CONTACT_EMAIL:-andrew@cogstack.org}"

PROJECT_ID="${GCP_PROJECT_ID:-cogstack-platform-ci}"
ZONE="${GCP_ZONE:-europe-west2-a}"
REGION="${ZONE%-*}"

# <service> <quota id> <dimension, or - for none>
# One PR environment is a zonal cluster of two e2-standard-4 nodes, with SSD
# boot disks and volumes and a load balancer.
QUOTAS="
compute.googleapis.com    SSD-TOTAL-GB-per-project-region       region=$REGION
compute.googleapis.com    CPUS-ALL-REGIONS-per-project          -
compute.googleapis.com    IN-USE-ADDRESSES-per-project-region   region=$REGION
container.googleapis.com  ClustersPerZone                       zone=$ZONE
"

log() { echo "==> $*" >&2; }

# current_limit <service> <quota id> <dimension>: the limit set for that
# dimension, or the quota's default where the project has none of its own.
current_limit() {
  local key="${3%%=*}" value="${3#*=}"
  gcloud quotas info describe "$2" --service "$1" --project "$PROJECT_ID" --format json |
    jq -r --arg key "$key" --arg value "$value" '
      .dimensionsInfos
      | (map(select(.dimensions[$key]? == $value)) + map(select((.dimensions // {}) == {})))
      | .[0].details.value // empty'
}

extra=(--email "$QUOTA_CONTACT_EMAIL")
[[ -n "${DRY_RUN:-}" ]] && extra+=(--validate-only)

while read -r service quota dimension; do
  [[ -n "$service" ]] || continue
  limit="$(current_limit "$service" "$quota" "$dimension")"
  if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
    echo "Could not read the current limit of $quota (got '$limit')" >&2
    exit 1
  fi

  args=()
  id="pr-environments-${quota}"
  if [[ "$dimension" != "-" ]]; then
    args+=(--dimensions "$dimension")
    id+="-${dimension#*=}"
  fi

  log "$quota ${dimension/#-/}: $limit -> $((limit * 2))"
  # "update --allow-missing" creates the request, or changes the one an earlier
  # run filed under the same ID.
  gcloud quotas preferences update "$(tr '[:upper:]' '[:lower:]' <<< "$id")" \
    --service "$service" --project "$PROJECT_ID" \
    --quota-id "$quota" --preferred-value "$((limit * 2))" \
    --justification "More concurrent per-pull-request GKE test environments" \
    --allow-missing ${args[@]+"${args[@]}"} ${extra[@]+"${extra[@]}"}
done <<< "$QUOTAS"
