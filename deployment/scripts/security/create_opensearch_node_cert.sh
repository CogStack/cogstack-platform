#!/usr/bin/env bash

# =============================================================================================================================
# Create OpenSearch node certificates, keys, and Java stores using the shared root CA.
#
# Usage:
#     ./create_opensearch_node_cert.sh [--days DAYS] <hostname> [hostname ...]
#
# Requires:
#     - Bash, OpenSSL and Java keytool
#     - OS_CERTIFICATE_PASSWORD for the PKCS#12 bundle and Java stores
#     - root-ca.pem and root-ca.key under certificates/root/ in SECURITY_DIR
#
# Optional settings:
#     - --days defaults to 1460.
#     - SECURITY_DIR defaults to deployment/security/.
#     - OPENSEARCH_NODE_DNS_NAMES adds comma-separated DNS names to every node certificate.
#     - Each certificate covers the node hostname and the Compose service name opensearch.
#
# Outputs under certificates/opensearch/:
#     elastic-stack-ca.crt.pem     - Public root CA certificate
#     <hostname>.key               - PKCS#8 RSA private key
#     <hostname>.csr               - Certificate signing request
#     <hostname>.crt               - Signed PEM certificate
#     <hostname>.p12               - Encrypted PKCS#12 bundle with the key and chain
#     <hostname>-keystore.jks      - Java keystore with the key and chain
#     <hostname>-truststore.key    - JKS truststore containing the node certificate
# =============================================================================================================================

set -euo pipefail
umask 077

days=1460
if [[ ${1:-} == --days ]]; then
    if [[ ! ${2:-} =~ ^[1-9][0-9]*$ ]]; then
        printf '%s\n' '--days must be a positive integer.' >&2
        exit 2
    fi
    days=$2
    shift 2
fi
if (( $# == 0 )); then
    printf 'Usage: %s [--days DAYS] <hostname> [hostname ...]\n' "$0" >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
security_dir=${SECURITY_DIR:-"$script_dir/../../security"}
ca_cert="$security_dir/certificates/root/root-ca.pem"
ca_key="$security_dir/certificates/root/root-ca.key"
output_dir="$security_dir/certificates/opensearch"
ca_alias="$output_dir/elastic-stack-ca.crt.pem"

hostname_pattern='^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)*[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$'
validate_hostname() {
    if (( ${#1} > 253 )) || [[ ! "$1" =~ $hostname_pattern || "$1" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
        printf 'Invalid OpenSearch DNS hostname: %s\n' "$1" >&2
        exit 2
    fi
}

san_names=(opensearch)
if [[ -n ${OPENSEARCH_NODE_DNS_NAMES:-} ]]; then
    if [[ ! "$OPENSEARCH_NODE_DNS_NAMES" =~ ^[A-Za-z0-9.-]+(,[A-Za-z0-9.-]+)*$ ]]; then
        printf '%s\n' 'OPENSEARCH_NODE_DNS_NAMES must contain comma-separated DNS hostnames.' >&2
        exit 2
    fi
    IFS=, read -r -a extra_names <<< "$OPENSEARCH_NODE_DNS_NAMES"
    for name in "${extra_names[@]}"; do
        validate_hostname "$name"
        san_names+=("$name")
    done
fi

require_new_file() {
    if [[ -e "$1" || -L "$1" ]]; then
        printf 'Output already exists: %s\n' "$1" >&2
        exit 1
    fi
}

suffixes=(.key .csr .crt .p12 -keystore.jks -truststore.key)
shopt -s nocasematch
for node in "$@"; do
    validate_hostname "$node"
    if (( ${#node} > 64 )) || [[ "$node" == root-ca || "$node" == admin || "$node" == client ]]; then
        printf 'Use a node hostname up to 64 characters, distinct from root-ca, admin and client: %s\n' "$node" >&2
        exit 2
    fi
    for suffix in "${suffixes[@]}"; do
        require_new_file "$output_dir/$node$suffix"
    done
done

for input in "$ca_cert" "$ca_key"; do
    if [[ ! -f "$input" || ! -r "$input" || ! -s "$input" ]]; then
        printf 'Missing or unreadable CA file %s. Run create_root_ca_cert.sh first.\n' "$input" >&2
        exit 1
    fi
done

write_ca_alias=true
if [[ -e "$ca_alias" || -L "$ca_alias" ]]; then
    if [[ ! -f "$ca_alias" ]] || ! cmp -s -- "$ca_cert" "$ca_alias"; then
        printf 'Existing OpenSearch CA differs from %s: %s\n' "$ca_cert" "$ca_alias" >&2
        exit 1
    fi
    write_ca_alias=false
fi

# shellcheck source=password_prompt.sh
source "$script_dir/password_prompt.sh"
require_password OS_CERTIFICATE_PASSWORD

# Stage all node bundles before writing deployment files. Roll back writes on failure.
scratch_dir=$(mktemp -d)
published=()
cleanup() {
    if (( $? != 0 )) && [[ -n ${published[0]:-} ]]; then
        rm -f -- "${published[@]}"
    fi
    rm -rf -- "$scratch_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# DNS names are case-insensitive. Keep each SAN only once.
for node in "$@"; do
    mkdir -- "$scratch_dir/$node"
    stage="$scratch_dir/$node/$node"
    sans="DNS:$node"
    for name in "${san_names[@]}"; do
        if [[ ",$sans," != *",DNS:$name,"* ]]; then
            sans+=",DNS:$name"
        fi
    done
    subject="/C=UK/ST=London/L=UK/O=cogstack/OU=cogstack/CN=$node"

    # Issue a leaf valid for both sides of OpenSearch node transport TLS.
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$stage.key"
    openssl req -new -sha256 -key "$stage.key" -subj "$subject" \
        -out "$stage.csr" -addext "subjectAltName=$sans"
    serial=$(openssl rand -hex 16)
    openssl x509 -req -sha256 -days "$days" -set_serial "0x$serial" \
        -in "$stage.csr" -CA "$ca_cert" -CAkey "$ca_key" -out "$stage.crt" \
        -extfile <(printf '%s\n' 'basicConstraints=critical,CA:FALSE' \
            'keyUsage=critical,digitalSignature,keyEncipherment' 'extendedKeyUsage=serverAuth,clientAuth' \
            'subjectKeyIdentifier=hash' 'authorityKeyIdentifier=keyid,issuer' "subjectAltName=$sans")
    openssl verify -CAfile "$ca_cert" "$stage.crt" >/dev/null

    # Preserve OpenSearch's original aliases and the separate leaf-pinning truststore.
    openssl pkcs12 -export -name "$node" -inkey "$stage.key" -in "$stage.crt" \
        -certfile "$ca_cert" -out "$stage.p12" -keypbe AES-256-CBC -certpbe AES-256-CBC \
        -passout env:OS_CERTIFICATE_PASSWORD
    keytool -importkeystore -noprompt -alias "$node" \
        -srckeystore "$stage.p12" -srcstoretype PKCS12 -srcstorepass:env OS_CERTIFICATE_PASSWORD \
        -destkeystore "$stage-keystore.jks" -deststoretype JKS \
        -deststorepass:env OS_CERTIFICATE_PASSWORD -destkeypass:env OS_CERTIFICATE_PASSWORD
    keytool -importcert -noprompt -alias root-ca -file "$ca_cert" \
        -keystore "$stage-keystore.jks" -storetype JKS -storepass:env OS_CERTIFICATE_PASSWORD
    keytool -importcert -noprompt -alias "$node" -file "$stage.crt" \
        -keystore "$stage-truststore.key" -storetype JKS -storepass:env OS_CERTIFICATE_PASSWORD
done

# Private files inherit mode 0600, and noclobber protects concurrent writes.
set -o noclobber
publish() {
    local source=$1 target=$2 mode=$3
    require_new_file "$target"
    {
        published+=("$target")
        cat -- "$source"
    } > "$target"
    chmod -- "$mode" "$target"
}
(umask 022; mkdir -p -- "$output_dir")
for node in "$@"; do
    for suffix in "${suffixes[@]}"; do
        case "$suffix" in
            .key|.p12|-keystore.jks) mode=0600 ;;
            *) mode=0644 ;;
        esac
        publish "$scratch_dir/$node/$node$suffix" "$output_dir/$node$suffix" "$mode"
    done
done
if [[ "$write_ca_alias" == true ]]; then
    publish "$ca_cert" "$ca_alias" 0644
fi
printf 'Created OpenSearch node certificates and Java stores under %s\n' "$output_dir"
