#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../env/general.env
source "$script_dir/../../env/general.env"
namespace="${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"
auth_file="${NIFI_AUTH_FILE:-$script_dir/../../env/authentication.env}"
# shellcheck disable=SC1090 # Optional deployment credentials.
if [[ -f "$auth_file" || -n ${NIFI_AUTH_FILE:-} ]]; then source "$auth_file"; fi
# shellcheck source=password_prompt.sh
source "$script_dir/password_prompt.sh"

if [[ -z ${NIFI_SINGLE_USER_CREDENTIALS_USERNAME:-} && -t 0 ]]; then
    IFS= read -r -p 'NiFi username: ' NIFI_SINGLE_USER_CREDENTIALS_USERNAME
fi
: "${NIFI_SINGLE_USER_CREDENTIALS_USERNAME:?Set NIFI_SINGLE_USER_CREDENTIALS_USERNAME or run in a terminal}"
# Reserve the checked-in password for Compose development.
if [[ ${NIFI_SINGLE_USER_CREDENTIALS_PASSWORD:-} == cogstackNiFi ]]; then
    unset NIFI_SINGLE_USER_CREDENTIALS_PASSWORD
fi
require_password NIFI_SINGLE_USER_CREDENTIALS_PASSWORD
password=$NIFI_SINGLE_USER_CREDENTIALS_PASSWORD
if [[ "$password" == *[$'\r\n']* || ${#password} -lt 12 ]] ||
    (LC_ALL=C; (( ${#password} > 72 ))); then
    printf 'NiFi login password must be one line, at least 12 characters and at most 72 bytes.\n' >&2
    exit 1
fi
if [[ "$NIFI_SINGLE_USER_CREDENTIALS_USERNAME" == *[[:cntrl:]:]* || "$NIFI_SINGLE_USER_CREDENTIALS_USERNAME" == \#* ]]; then
    printf 'NiFi username cannot contain colons or control characters, or start with #.\n' >&2
    exit 1
fi
salt=$(openssl rand -hex 8)
hash=$(openssl passwd -6 -salt "rounds=100000\$$salt" -stdin <<< "$password")
NIFI_HTPASSWD="$NIFI_SINGLE_USER_CREDENTIALS_USERNAME:$hash"

existing=$(kubectl -n "$namespace" get secret nifi-auth --ignore-not-found -o json)
version=$(jq -r '.metadata.resourceVersion' <<< "$existing")
key=$(jq -r '.data.NIFI_SENSITIVE_PROPS_KEY // "" | @base64d' <<< "$existing")
NIFI_SENSITIVE_PROPS_KEY=${key:-${NIFI_SENSITIVE_PROPS_KEY:-$(openssl rand -hex 16)}}
export NIFI_SENSITIVE_PROPS_KEY NIFI_HTPASSWD

manifest=$(jq -n --arg version "$version" '{
    apiVersion: "v1", kind: "Secret",
    metadata: {name: "nifi-auth", resourceVersion: (if $version == "" then null else $version end)},
    stringData: {
        htpasswd: env.NIFI_HTPASSWD,
        NIFI_SENSITIVE_PROPS_KEY: env.NIFI_SENSITIVE_PROPS_KEY
    }
}')
if [[ -z "$version" ]]; then
    kubectl -n "$namespace" create -f - <<< "$manifest"
else
    kubectl -n "$namespace" replace -f - <<< "$manifest"
fi
