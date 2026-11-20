#!/usr/bin/env bash
# Tear down PR environments that should no longer exist: the PR is closed, or
# the cluster is older than MAX_AGE_HOURS. With "all", tear down every one.
# Usage: reap.sh [all]      (needs GH_TOKEN and GH_REPO for the PR lookup)
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ./lib.sh

MODE="${1:-stale}"
MAX_AGE_HOURS="${MAX_AGE_HOURS:-24}"
now="$(date +%s)"
failed=0

while read -r pr created; do
  [[ -n "$pr" ]] || continue
  age_hours=$(((now - $(date -d "$created" +%s)) / 3600))
  state="$(gh pr view "$pr" --json state --jq .state 2>/dev/null || echo UNKNOWN)"

  reason=""
  if [[ "$MODE" == "all" ]]; then
    reason="teardown of all environments requested"
  elif [[ "$state" == "CLOSED" || "$state" == "MERGED" ]]; then
    reason="PR is $state"
  elif ((age_hours >= MAX_AGE_HOURS)); then
    reason="cluster is ${age_hours}h old (limit ${MAX_AGE_HOURS}h)"
  fi

  if [[ -n "$reason" ]]; then
    log "Reaping PR $pr: $reason"
    ./teardown.sh "$pr" || failed=1
  else
    log "Keeping PR $pr (state $state, ${age_hours}h old); refreshing its status"
    ./pr-status.sh "$pr" live || true
  fi
done < <(gc container clusters list --filter="resourceLabels.${CLUSTER_LABEL}" \
  --format='value(resourceLabels.pr,createTime)')

exit "$failed"
