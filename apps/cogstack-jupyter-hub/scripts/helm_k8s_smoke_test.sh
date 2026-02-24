#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_PATH="${ROOT_DIR}/charts/cogstack-jupyterhub"

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is required for this smoke test." >&2
  exit 1
fi

if [[ ! -d "${CHART_PATH}" ]]; then
  echo "Chart path not found: ${CHART_PATH}" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d /tmp/cogstack-helm-smoke.XXXXXX)"
DEFAULT_RENDER="${WORK_DIR}/render-default.yaml"
SETFILE_RENDER="${WORK_DIR}/render-set-file.yaml"

echo "[1/5] Lint chart"
helm lint "${CHART_PATH}"

echo "[2/5] Render chart with bundled files"
helm template cogstack-jupyterhub "${CHART_PATH}" > "${DEFAULT_RENDER}"

echo "[3/5] Render chart using repo env/config/security files via --set-file"
helm template cogstack-jupyterhub "${CHART_PATH}" \
  --set envFiles.useBundled=false \
  --set hubFiles.useBundled=false \
  --set securityFiles.useBundled=false \
  --set-file envFiles.jupyter="${ROOT_DIR}/env/jupyter.env" \
  --set-file envFiles.general="${ROOT_DIR}/env/general.env" \
  --set-file hubFiles.jupyterhubConfig="${ROOT_DIR}/config/jupyterhub_config.py" \
  --set-file hubFiles.userlist="${ROOT_DIR}/config/userlist" \
  --set-file hubFiles.teamlist="${ROOT_DIR}/config/teamlist" \
  --set-file securityFiles.cookieSecret="${ROOT_DIR}/config/jupyterhub_cookie_secret" \
  --set-file securityFiles.tlsKey="${ROOT_DIR}/security/nifi.key" \
  --set-file securityFiles.tlsCert="${ROOT_DIR}/security/nifi.pem" \
  > "${SETFILE_RENDER}"

for manifest in "${DEFAULT_RENDER}" "${SETFILE_RENDER}"; do
  grep -q '^kind: Deployment$' "${manifest}" || {
    echo "Missing Deployment in ${manifest}" >&2
    exit 1
  }
  grep -q '^kind: Service$' "${manifest}" || {
    echo "Missing Service in ${manifest}" >&2
    exit 1
  }
  grep -q '^kind: ConfigMap$' "${manifest}" || {
    echo "Missing ConfigMap in ${manifest}" >&2
    exit 1
  }
  grep -q '^kind: Secret$' "${manifest}" || {
    echo "Missing Secret in ${manifest}" >&2
    exit 1
  }
 done

echo "[4/5] Resource presence checks passed"

if command -v kubectl >/dev/null 2>&1; then
  if kubectl cluster-info >/dev/null 2>&1; then
    echo "[5/5] kubectl server dry-run validation against current cluster"
    kubectl apply --dry-run=server -f "${DEFAULT_RENDER}" >/dev/null
    kubectl apply --dry-run=server -f "${SETFILE_RENDER}" >/dev/null
  else
    echo "[5/5] kubectl found but no cluster is reachable; skipping Kubernetes API validation"
  fi
else
  echo "[5/5] kubectl not found; skipping Kubernetes API validation"
fi

echo "Helm/Kubernetes smoke tests passed. Rendered manifests are in ${WORK_DIR}"
