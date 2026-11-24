#!/usr/bin/env bash

# =============================================================================================================================
# 🔐 Create the NGINX HTTPS certificate and private key
#
# Usage:
#     ./create_nginx_certs.sh [--days DAYS]
#     DAYS is a positive integer. The default validity is 397 days.
#
# Requires:
#     - Bash and OpenSSL
#     - root-ca.pem and root-ca.key under certificates/root/ in SECURITY_DIR
#
# Optional environment variables:
#     - SECURITY_DIR defaults to deployment/security/
#     - NGINX_TLS_NAMES is a comma-separated list of HTTPS hostnames or IP addresses
#       and defaults to localhost,127.0.0.1. Wildcards such as *.cogstack.internal are supported.
#
# Output:
#     deployment/security/certificates/nginx/tls.crt - CA-signed HTTPS certificate in PEM format
#     deployment/security/certificates/nginx/tls.key - RSA private key with mode 0600
# =============================================================================================================================

set -euo pipefail
umask 077

days=397
if (( $# > 0 )); then
    if [[ $# -ne 2 || "$1" != --days || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        printf 'Usage: %s [--days DAYS] (DAYS must be a positive integer)\n' "$0" >&2
        exit 2
    fi
    days=$2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
security_dir=${SECURITY_DIR:-"$script_dir/../../security"}
ca_cert="$security_dir/certificates/root/root-ca.pem"
ca_key="$security_dir/certificates/root/root-ca.key"
output_dir="$security_dir/certificates/nginx"

for input in "$ca_cert" "$ca_key"; do
    if [[ ! -f "$input" || ! -r "$input" || ! -s "$input" ]]; then
        printf 'Missing or unreadable CA file %s. Run create_root_ca_cert.sh first.\n' "$input" >&2
        exit 1
    fi
done

require_new_file() {
    if [[ -e "$1" || -L "$1" ]]; then
        printf 'Output already exists: %s\n' "$1" >&2
        exit 1
    fi
}
require_new_file "$output_dir/tls.key"
require_new_file "$output_dir/tls.crt"

# === Build the SAN list for the names clients use to reach NGINX
tls_names=${NGINX_TLS_NAMES:-localhost,127.0.0.1}
if [[ "$tls_names" == ,* || "$tls_names" == *, || "$tls_names" == *,,* || "$tls_names" == *[[:space:]]* ]]; then
    printf 'NGINX_TLS_NAMES must contain comma-separated hostnames or IP addresses without spaces.\n' >&2
    exit 2
fi
IFS=, read -r -a names <<< "$tls_names"
dns_label='[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
dns_name="^$dns_label(\.$dns_label)*$"
wildcard_name="^\*\.$dns_label(\.$dns_label)+$"
sans=
for name in "${names[@]}"; do
    if [[ "$name" =~ ^[0-9]+(\.[0-9]+){3}$ || ( "$name" == *:* && "$name" =~ ^[[:xdigit:]:.]+$ ) ]]; then
        type=IP
    elif (( ${#name} <= 253 )) && [[ "$name" =~ $dns_name || "$name" =~ $wildcard_name ]]; then
        type=DNS
    else
        printf 'Invalid NGINX TLS hostname or IP address: %s\n' "$name" >&2
        exit 2
    fi
    sans+="${sans:+,}$type:$name"
done

# Finish and verify both files before publishing the pair.
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

# === Generate the key and issue a server certificate
openssl req -new -newkey rsa:4096 -nodes -sha256 -subj '/CN=CogStack NGINX' \
    -keyout "$scratch_dir/tls.key" -out "$scratch_dir/tls.csr"
serial=$(openssl rand -hex 16)
openssl x509 -req -sha256 -days "$days" -set_serial "0x$serial" \
    -in "$scratch_dir/tls.csr" -CA "$ca_cert" -CAkey "$ca_key" -out "$scratch_dir/tls.crt" \
    -extfile <(printf '%s\n' 'basicConstraints=critical,CA:FALSE' \
        'keyUsage=critical,digitalSignature,keyEncipherment' 'extendedKeyUsage=serverAuth' \
        'subjectKeyIdentifier=hash' 'authorityKeyIdentifier=keyid,issuer' "subjectAltName=$sans")
openssl verify -purpose sslserver -CAfile "$ca_cert" "$scratch_dir/tls.crt" >/dev/null

# === Publish the certificate and key at the NGINX mount paths
(umask 022; mkdir -p -- "$output_dir")
set -o noclobber
for file in tls.key tls.crt; do
    require_new_file "$output_dir/$file"
    {
        published+=("$output_dir/$file")
        cat -- "$scratch_dir/$file"
    } > "$output_dir/$file"
done
chmod 644 "$output_dir/tls.crt"
printf 'Created NGINX certificate and key under %s\n' "$output_dir"
