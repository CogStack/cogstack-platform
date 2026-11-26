#!/usr/bin/env bash
set -euo pipefail

service=${1:-}
case "$service" in
    opensearch|opensearch-dashboards) ;;
    *) printf '%s\n' 'Specify opensearch or opensearch-dashboards.' >&2; exit 2 ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../env/general.env
source "$script_dir/../../env/general.env"
namespace="${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"
pod=opensearch-cluster-master-0

if [[ "$service" == opensearch ]]; then
    status=$(kubectl -n "$namespace" exec "$pod" -- curl -sS --noproxy '*' \
        --retry 3 --retry-delay 2 --retry-connrefused --max-time 10 \
        --cacert /usr/share/opensearch/config/tls/ca.crt --output /dev/null \
        --write-out '%{http_code}' https://localhost:9200/_plugins/_security/health)
    case "$status" in
        200) printf '%s\n' 'OpenSearch Security is already initialized.'; exit 0 ;;
        503) ;;
        *) printf 'OpenSearch Security health check returned HTTP %s.\n' "$status" >&2; exit 1 ;;
    esac
fi

auth_file=${OPENSEARCH_AUTH_FILE:-$script_dir/../../env/authentication.env}
# shellcheck disable=SC1090 # Optional deployment credentials.
if [[ -f "$auth_file" || -n ${OPENSEARCH_AUTH_FILE:-} ]]; then source "$auth_file"; fi
# shellcheck source=password_prompt.sh
source "$script_dir/password_prompt.sh"

OPENSEARCH_KIBANA_PASSWORD=${OPENSEARCH_KIBANA_PASSWORD:-${KIBANA_PASSWORD:-}}
existing=
if [[ "$service" == opensearch-dashboards || -z "$OPENSEARCH_KIBANA_PASSWORD" ]]; then
    existing=$(kubectl -n "$namespace" get secret dashboards-auth --ignore-not-found -o json)
fi
if [[ -z "$OPENSEARCH_KIBANA_PASSWORD" && -n "$existing" ]]; then
    # Append a character so command substitution preserves trailing newlines.
    stored_password=$(jq -j '(.data.password // "" | @base64d) + "."' <<< "$existing")
    OPENSEARCH_KIBANA_PASSWORD=${stored_password%.}
fi
require_password OPENSEARCH_KIBANA_PASSWORD

if [[ "$service" == opensearch ]]; then
    export OPENSEARCH_NIFI_PASSWORD OPENSEARCH_PIPELINE_PASSWORD OPENSEARCH_ANALYST_PASSWORD \
        OS_NIFI_PASSWORD OS_PIPELINE_PASSWORD OS_ANALYST_PASSWORD
    exec bash "$script_dir/../../../apps/opensearch/security/bootstrap.sh" kubectl -n "$namespace" exec -i "$pod" --
fi

DASHBOARDS_COOKIE_DATA=$(jq -r '.data.cookie // ""' <<< "$existing")
if [[ -z "$DASHBOARDS_COOKIE_DATA" ]]; then
    cookie=$(openssl rand -hex 16)
    DASHBOARDS_COOKIE_DATA=$(printf '%s' "$cookie" | openssl base64 -A)
fi
export DASHBOARDS_COOKIE_DATA

manifest=$(jq -s '.[0] | {
    apiVersion: "v1", kind: "Secret", type: "Opaque",
    metadata: {name: "dashboards-auth", resourceVersion: .metadata.resourceVersion},
    data: {
        username: ("kibanaserver" | @base64),
        password: (env.OPENSEARCH_KIBANA_PASSWORD | @base64),
        cookie: env.DASHBOARDS_COOKIE_DATA
    }
}' <<< "$existing")
if [[ -z "$existing" ]]; then
    kubectl -n "$namespace" create -f - <<< "$manifest"
else
    kubectl -n "$namespace" patch secret dashboards-auth --type=merge --patch-file=/dev/stdin <<< "$manifest"
fi
