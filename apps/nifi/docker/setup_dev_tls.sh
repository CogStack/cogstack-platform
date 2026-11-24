#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ $# -ne 1 || -z ${1:-} ]]; then
    printf 'Usage: %s <certificates-env-file>\n' "$0" >&2
    exit 1
fi

env_file=$1
[[ "$env_file" == /* ]] || env_file="$PWD/$env_file"
if [[ ! -f "$env_file" || ! -r "$env_file" ]]; then
    printf 'Cannot read certificate settings at %s.\n' "$env_file" >&2
    exit 1
fi

unset SECURITY_DIR ROOT_CERTIFICATE_KEYSTORE_PASSWORD KEYSTORE_PASSWORD TRUSTSTORE_PASSWORD
unset NIFI_UPSTREAM_TLS_NAME NIFI_HEALTHCHECK_HOST KUBE_NAMESPACE CLUSTER_DOMAIN NGINX_TLS_NAMES
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

: "${ROOT_CERTIFICATE_KEYSTORE_PASSWORD:?Set ROOT_CERTIFICATE_KEYSTORE_PASSWORD in the certificate env file}"
: "${KEYSTORE_PASSWORD:?Set KEYSTORE_PASSWORD in the certificate env file}"
: "${TRUSTSTORE_PASSWORD:?Set TRUSTSTORE_PASSWORD in the certificate env file}"
if [[ ${SECURITY_DIR:-} != /* ]]; then
    printf 'Set SECURITY_DIR to an absolute path in %s.\n' "$env_file" >&2
    exit 1
fi

while [[ "$SECURITY_DIR" != / && "$SECURITY_DIR" == */ ]]; do
    SECURITY_DIR=${SECURITY_DIR%/}
done
certs="$SECURITY_DIR/certificates"

valid_bundle() {
    local path
    for path in "$SECURITY_DIR" "$certs" "$certs/"{root,nifi,nginx}; do
        [[ -d "$path" && ! -L "$path" ]] || return 1
    done
    for path in "$certs/root/root-ca.pem" \
        "$certs/nifi/"nifi-{keystore,truststore}.jks "$certs/nginx/"tls.{crt,key}; do
        [[ -f "$path" && ! -L "$path" && -r "$path" && -s "$path" ]] || return 1
    done

    keytool -list -storetype JKS -keystore "$certs/nifi/nifi-keystore.jks" \
        -storepass:env KEYSTORE_PASSWORD >/dev/null 2>&1 &&
        keytool -list -storetype JKS -keystore "$certs/nifi/nifi-truststore.jks" \
            -storepass:env TRUSTSTORE_PASSWORD >/dev/null 2>&1
}

mkdir -p -- "$(dirname -- "$SECURITY_DIR")"
if ! mkdir -- "$SECURITY_DIR" 2>/dev/null; then
    valid_bundle && exit 0
    printf 'Cannot create or reuse demo TLS bundle at %s. Use a new directory or fix the existing bundle.\n' "$SECURITY_DIR" >&2
    exit 1
fi

# Only remove a directory reserved by this invocation.
trap 'rm -rf -- "$SECURITY_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
generators="$script_dir/../../../deployment/scripts/security"
"$generators/create_root_ca_cert.sh" >/dev/null
"$generators/create_nifi_certs.sh" >/dev/null
"$generators/create_nginx_certs.sh" >/dev/null
trap - EXIT
