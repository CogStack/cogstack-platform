#!/usr/bin/env bash

# =============================================================================================================================
# 🔐 Create the OpenSearch Dashboards and admin certificates and keys
#
# Usage:
#     ./create_opensearch_client_admin_certs.sh [--admin-only|--dashboards-only] [--days DAYS]
#     --admin-only skips the Dashboards certificate and PKCS#12 bundle.
#     --dashboards-only skips the admin client certificate.
#     DAYS is a positive integer. The default validity is 1,460 days.
#
# Requires:
#     - Bash and OpenSSL
#     - OS_CERTIFICATE_PASSWORD for the encrypted Dashboards PKCS#12 bundle
#     - root-ca.pem and root-ca.key under certificates/root/ in SECURITY_DIR
#
# Optional environment variables:
#     - SECURITY_DIR defaults to deployment/security/
#     - OPENSEARCH_DASHBOARDS_DNS_NAMES adds comma-separated DNS names to
#       opensearch-dashboards and kibana
#
# Output:
#     deployment/security/certificates/opensearch/es_kibana_client.key - Dashboards RSA private key in PKCS#8 format
#     deployment/security/certificates/opensearch/es_kibana_client.csr - Dashboards certificate signing request
#     deployment/security/certificates/opensearch/es_kibana_client.pem - Signed Dashboards certificate in PEM format
#     deployment/security/certificates/opensearch/es_kibana_client.p12 - Encrypted PKCS#12 bundle with the key and chain
#     deployment/security/certificates/opensearch/admin.key.pem        - Admin RSA private key in PKCS#8 format
#     deployment/security/certificates/opensearch/admin.csr            - Admin certificate signing request
#     deployment/security/certificates/opensearch/admin.crt            - Signed admin client certificate in PEM format
# =============================================================================================================================

set -euo pipefail
umask 077

days=1460
mode=
case ${1:-} in
    --admin-only|--dashboards-only) mode=$1; shift ;;
esac
if (( $# > 0 )); then
    if [[ $# -ne 2 || "$1" != --days || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        printf 'Usage: %s [--admin-only|--dashboards-only] [--days DAYS] (DAYS must be a positive integer)\n' "$0" >&2
        exit 2
    fi
    days=$2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
security_dir=${SECURITY_DIR:-"$script_dir/../../security"}
ca_cert="$security_dir/certificates/root/root-ca.pem"
ca_key="$security_dir/certificates/root/root-ca.key"
output_dir="$security_dir/certificates/opensearch"

for input in "$ca_cert" "$ca_key"; do
    if [[ ! -f "$input" || ! -r "$input" || ! -s "$input" ]]; then
        printf 'Missing or unreadable CA file %s. Run create_root_ca_cert.sh first.\n' "$input" >&2
        exit 1
    fi
done

roles=()
files=()
if [[ "$mode" != --admin-only ]]; then
    # shellcheck source=password_prompt.sh
    source "$script_dir/password_prompt.sh"
    require_password OS_CERTIFICATE_PASSWORD
    roles=(client)
    files=(es_kibana_client.pem es_kibana_client.key es_kibana_client.csr es_kibana_client.p12)

    sans=DNS:opensearch-dashboards,DNS:kibana
    if [[ -n "${OPENSEARCH_DASHBOARDS_DNS_NAMES:-}" ]]; then
        dns_label='[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?'
        dns_name="$dns_label(\.$dns_label)*"
        if [[ ! "$OPENSEARCH_DASHBOARDS_DNS_NAMES" =~ ^$dns_name(,$dns_name)*$ ]]; then
            printf 'OPENSEARCH_DASHBOARDS_DNS_NAMES must contain comma-separated DNS names.\n' >&2
            exit 2
        fi
        sans+=",DNS:${OPENSEARCH_DASHBOARDS_DNS_NAMES//,/,DNS:}"
    fi
fi
if [[ "$mode" != --dashboards-only ]]; then
    roles+=(admin)
    files+=(admin.crt admin.key.pem admin.csr)
fi

for file in "${files[@]}"; do
    if [[ -e "$output_dir/$file" || -L "$output_dir/$file" ]]; then
        printf 'Output already exists: %s\n' "$output_dir/$file" >&2
        exit 1
    fi
done

# Finish both certificates and the bundle before publishing any outputs.
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

subject='/C=UK/ST=London/L=UK/O=cogstack/OU=cogstack'
for role in "${roles[@]}"; do
    if [[ "$role" == client ]]; then
        key=es_kibana_client.key
        csr=es_kibana_client.csr
        cert=es_kibana_client.pem
        extensions=('keyUsage=critical,digitalSignature,keyEncipherment' 'extendedKeyUsage=serverAuth,clientAuth' "subjectAltName=$sans")
    else
        key=admin.key.pem
        csr=admin.csr
        cert=admin.crt
        extensions=('keyUsage=critical,digitalSignature' 'extendedKeyUsage=clientAuth')
    fi

    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$scratch_dir/$key"
    openssl req -new -sha256 -key "$scratch_dir/$key" -subj "$subject/CN=$role" -out "$scratch_dir/$csr"
    serial=$(openssl rand -hex 16)
    openssl x509 -req -sha256 -days "$days" -set_serial "0x$serial" \
        -in "$scratch_dir/$csr" -CA "$ca_cert" -CAkey "$ca_key" -out "$scratch_dir/$cert" \
        -extfile <(printf '%s\n' 'basicConstraints=critical,CA:FALSE' \
            'subjectKeyIdentifier=hash' 'authorityKeyIdentifier=keyid,issuer' "${extensions[@]}")
    openssl verify -CAfile "$ca_cert" "$scratch_dir/$cert" >/dev/null
done

if [[ "$mode" != --admin-only ]]; then
    openssl pkcs12 -export -name es_kibana_client -inkey "$scratch_dir/es_kibana_client.key" \
        -in "$scratch_dir/es_kibana_client.pem" -certfile "$ca_cert" -out "$scratch_dir/es_kibana_client.p12" \
        -keypbe AES-256-CBC -certpbe AES-256-CBC -passout env:OS_CERTIFICATE_PASSWORD
fi

(umask 022; mkdir -p -- "$output_dir")
set -o noclobber
for file in "${files[@]}"; do
    {
        published+=("$output_dir/$file")
        cat -- "$scratch_dir/$file"
    } > "$output_dir/$file"
    case "$file" in
        *.crt|*.csr|es_kibana_client.pem) chmod 644 "$output_dir/$file" ;;
    esac
done
printf 'Created OpenSearch client certificates under %s\n' "$output_dir"
