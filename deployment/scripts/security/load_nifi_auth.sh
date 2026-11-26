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
require_password NIFI_SINGLE_USER_CREDENTIALS_PASSWORD
if (( ${#NIFI_SINGLE_USER_CREDENTIALS_PASSWORD} < 12 )); then
    printf 'NiFi login password must be at least 12 characters.\n' >&2
    exit 1
fi
KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:-${NIFI_KEYSTORE_PASSWORD:-}}
TRUSTSTORE_PASSWORD=${TRUSTSTORE_PASSWORD:-${NIFI_TRUSTSTORE_PASSWORD:-}}
if [[ "$auth_file" -ef "$script_dir/../../env/authentication_dev.env" ]]; then
    # shellcheck source=../../env/certificates_dev.env
    source "$script_dir/../../env/certificates_dev.env"
    KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:-${NIFI_KEYSTORE_PASSWORD:-}}
    TRUSTSTORE_PASSWORD=${TRUSTSTORE_PASSWORD:-${NIFI_TRUSTSTORE_PASSWORD:-}}
fi
require_password KEYSTORE_PASSWORD
require_password TRUSTSTORE_PASSWORD

existing=$(kubectl -n "$namespace" get secret nifi-auth --ignore-not-found -o json)
version=$(jq -r '.metadata.resourceVersion' <<< "$existing")
key=$(jq -r '.data.NIFI_SENSITIVE_PROPS_KEY // "" | @base64d' <<< "$existing")
NIFI_SENSITIVE_PROPS_KEY=${key:-${NIFI_SENSITIVE_PROPS_KEY:-$(openssl rand -hex 16)}}
NIFI_INITIAL_ADMIN_IDENTITY=${NIFI_INITIAL_ADMIN_IDENTITY:-$NIFI_SINGLE_USER_CREDENTIALS_USERNAME}
export NIFI_SENSITIVE_PROPS_KEY NIFI_INITIAL_ADMIN_IDENTITY NIFI_SINGLE_USER_CREDENTIALS_USERNAME

manifest=$(jq -n --arg version "$version" '{
    apiVersion: "v1", kind: "Secret",
    metadata: {name: "nifi-auth", resourceVersion: (if $version == "" then null else $version end)},
    stringData: {
        SINGLE_USER_CREDENTIALS_USERNAME: env.NIFI_SINGLE_USER_CREDENTIALS_USERNAME,
        SINGLE_USER_CREDENTIALS_PASSWORD: env.NIFI_SINGLE_USER_CREDENTIALS_PASSWORD,
        INITIAL_ADMIN_IDENTITY: env.NIFI_INITIAL_ADMIN_IDENTITY,
        KEYSTORE_PASSWORD: env.KEYSTORE_PASSWORD,
        TRUSTSTORE_PASSWORD: env.TRUSTSTORE_PASSWORD,
        NIFI_SENSITIVE_PROPS_KEY: env.NIFI_SENSITIVE_PROPS_KEY
    }
}')
if [[ -z "$version" ]]; then
    kubectl -n "$namespace" create -f - <<< "$manifest"
else
    kubectl -n "$namespace" patch secret nifi-auth --type=merge --patch-file=/dev/stdin <<< "$manifest"
fi
