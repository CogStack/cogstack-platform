#!/usr/bin/env bash
# Keep a status panel at the top of the PR description: one line per app with a
# link and a green or red dot, so a reviewer sees straight away what to click
# and whether it is up.
#
# Usage: pr-status.sh <pr-number> <deploying|live|failed|removed>
#   live       probes every app over public HTTPS and shows a dot per app
#   the others only change the headline
# Needs GH_TOKEN, and GH_REPO or GITHUB_REPOSITORY. "live" also needs gcloud.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
source ./lib.sh
set_pr "${1:?usage: pr-status.sh <pr-number> <state>}" || exit 1
STATE="${2:?usage: pr-status.sh <pr-number> <state>}"

REPO="${GH_REPO:-${GITHUB_REPOSITORY:?GH_REPO or GITHUB_REPOSITORY must be set}}"
START="<!-- pr-environment:start -->"
END="<!-- pr-environment:end -->"
WORK="$(mktemp -d)"

run_link=""
if [[ -n "${GITHUB_RUN_ID:-}" ]]; then
  run_link=" · [workflow run](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})"
fi
commit="$(gh api "repos/${REPO}/pulls/${PR_NUMBER}" --jq '.head.sha[0:7]')"
now="$(date -u '+%Y-%m-%d %H:%M UTC')"

app_title() {
  case "$1" in
    trainer) echo "MedCAT Trainer" ;;
    jupyter) echo "JupyterHub" ;;
    dashboards) echo "OpenSearch Dashboards" ;;
    medcat) echo "MedCAT Service (API)" ;;
    anoncat) echo "AnonCAT Service (API)" ;;
    ocr) echo "OCR Service (API)" ;;
    *) echo "$1" ;;
  esac
}

{
  echo "$START"
  case "$STATE" in
    deploying)
      echo "## 🟡 Test environment is deploying"
      echo
      echo "Commit \`${commit}\` is being deployed to \`${DOMAIN}\`. Links appear here when it is ready (about 20 minutes for a new environment, 7 for an update)."
      echo
      echo "<sub>Updated ${now}${run_link}</sub>"
      ;;
    failed)
      echo "## 🔴 Test environment failed to deploy"
      echo
      echo "Commit \`${commit}\` did not deploy. The cluster is left running for debugging; see the workflow run for the reason."
      echo
      echo "<sub>Updated ${now}${run_link}</sub>"
      ;;
    removed)
      echo "## ⚪ Test environment removed"
      echo
      echo "The environment for this PR has been torn down. If the PR is still open, re-run the **GKE deployment test** job or push a commit to bring it back."
      echo
      echo "<sub>Updated ${now}${run_link}</sub>"
      ;;
    live)
      password="$(gc secrets versions access latest --secret "$BASIC_AUTH_SECRET")"
      [[ -n "${GITHUB_ACTIONS:-}" ]] && echo "::add-mask::${password}" >&2
      rows=""
      down=0
      total=0
      for app in $APPS; do
        name="${app%%:*}"
        url="https://${name}.${DOMAIN}${app#*:}"
        code="$(curl -s -L -o /dev/null -m 20 -w '%{http_code}' -u "${BASIC_AUTH_USER}:${password}" "$url" || true)"
        total=$((total + 1))
        if [[ "$code" =~ ^2 ]]; then
          dot="🟢"
        else
          dot="🔴"
          down=$((down + 1))
        fi
        rows+="| ${dot} | **$(app_title "$name")** | ${url} |"$'\n'
      done
      if ((down == 0)); then
        echo "## 🟢 Test environment is live"
      else
        echo "## 🔴 Test environment: ${down} of ${total} apps not responding"
      fi
      echo
      echo "| | App | Link |"
      echo "|---|---|---|"
      printf '%s' "$rows"
      echo
      echo "**Sign in** with user \`${BASIC_AUTH_USER}\`. Get the password with:"
      echo "\`gcloud secrets versions access latest --secret ${BASIC_AUTH_SECRET} --project ${GCP_PROJECT_ID}\`"
      echo
      echo "<sub>Commit \`${commit}\` · checked ${now} · removed when the PR closes or after ${MAX_AGE_HOURS:-24} hours${run_link}</sub>"
      ;;
    *)
      echo "unknown state: $STATE" >&2
      exit 1
      ;;
  esac
  echo "$END"
} > "$WORK/panel.md"

# Replace the existing panel, or put a new one above the author's description.
gh api "repos/${REPO}/pulls/${PR_NUMBER}" --jq '.body // ""' > "$WORK/body.md"
python3 - "$WORK/body.md" "$WORK/panel.md" "$START" "$END" > "$WORK/new.md" <<'EOF'
import re, sys
body, panel = open(sys.argv[1]).read(), open(sys.argv[2]).read().strip()
start, end = sys.argv[3], sys.argv[4]
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)
if pattern.search(body):
    print(pattern.sub(lambda _: panel, body, count=1).strip())
else:
    print((panel + "\n\n" + body.strip()).strip())
EOF
gh api -X PATCH "repos/${REPO}/pulls/${PR_NUMBER}" -F "body=@${WORK}/new.md" --silent || exit 1

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat "$WORK/panel.md" >> "$GITHUB_STEP_SUMMARY"
fi
log "PR ${PR_NUMBER} status panel set to '${STATE}'"
