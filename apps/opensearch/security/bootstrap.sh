#!/usr/bin/env bash
set -euo pipefail
umask 077

if (( $# == 0 )); then
    printf 'Usage: bash %s <OpenSearch container exec command>\n' "$0" >&2
    exit 2
fi
: "${KIBANA_PASSWORD:?Set the Dashboards service account password}"

policy_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
certs=$(cd -- "${SECURITY_DIR:-$policy_dir/../../../deployment/security}/certificates/opensearch" && pwd -P)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
printf '%s\0' kibanaserver "$KIBANA_PASSWORD" nifi "${OS_NIFI_PASSWORD:-}" \
    cogstack_pipeline "${OS_PIPELINE_PASSWORD:-}" cogstack_user "${OS_ANALYST_PASSWORD:-}" > "$scratch/passwords"

bootstrap=$(cat <<'BASH'
set -euo pipefail
umask 077
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
tar -xf - -C "$work"

opensearch_home=${OPENSEARCH_HOME:-/usr/share/opensearch}
tools="$opensearch_home/plugins/opensearch-security/tools"
ca="$opensearch_home/config/tls/ca.crt"
status=$(curl -sS --noproxy '*' --retry 30 --retry-all-errors --retry-delay 3 --max-time 10 \
    --cacert "$ca" --cert "$work/admin.crt" --key "$work/admin.key.pem" \
    --head --output /dev/null --write-out '%{http_code}' https://localhost:9200/.opendistro_security)
if [[ "$status" != 404 ]]; then
    printf 'Bootstrap requires an empty Security index (index check returned HTTP %s).\n' "$status" >&2
    exit 1
fi

cp "$opensearch_home/config/opensearch-security"/{action_groups,allowlist,audit,config,nodes_dn}.yml "$work/"
{
    printf '_meta:\n  type: internalusers\n  config_version: 2\n'
    while IFS= read -r -d '' user && IFS= read -r -d '' password; do
        [[ -n "$password" ]] || continue
        hash=$("$tools/hash.sh" -p "$password")
        printf '%s:\n  hash: "%s"\n' "$user" "$hash"
    done < "$work/passwords"
} > "$work/internal_users.yml"
rm -- "$work/passwords"

"$tools/securityadmin.sh" -icl -cd "$work" -cacert "$ca" \
    -cert "$work/admin.crt" -key "$work/admin.key.pem"
BASH
)

tar -cf - -C "$scratch" passwords -C "$certs" admin.crt admin.key.pem \
    -C "$policy_dir" roles.yml roles_mapping.yml tenants.yml |
    "$@" bash -c "$bootstrap"
