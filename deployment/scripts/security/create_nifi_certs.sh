#!/usr/bin/env bash

# =============================================================================================================================
# 🔐 Create the NiFi certificate, private key, and keystore/truststore bundle
#
# Usage:
#     ./create_nifi_certs.sh [--days DAYS]
#     DAYS is a positive integer. The default validity is 397 days.
#
# Requires:
#     - Bash, OpenSSL and Java keytool
#     - KEYSTORE_PASSWORD and TRUSTSTORE_PASSWORD (prompted when unset)
#     - root-ca.pem and root-ca.key under certificates/root/ in SECURITY_DIR
#
# Optional environment variables:
#     - SECURITY_DIR defaults to deployment/security/
#     - NIFI_UPSTREAM_TLS_NAME and NIFI_HEALTHCHECK_HOST add the names used by those clients
#     - KUBE_NAMESPACE adds the NiFi web Service DNS name in CLUSTER_DOMAIN (defaults to cluster.local)
#
# Output:
#     deployment/security/certificates/nifi/nifi.key             - RSA private key
#     deployment/security/certificates/nifi/nifi.csr             - Certificate signing request
#     deployment/security/certificates/nifi/nifi.pem             - Signed certificate in PEM format
#     deployment/security/certificates/nifi/nifi.crt             - The same certificate in binary DER format
#     deployment/security/certificates/nifi/nifi.p12             - Encrypted PKCS#12 bundle with the key and chain
#     deployment/security/certificates/nifi/nifi-keystore.jks    - Java keystore with the key and chain
#     deployment/security/certificates/nifi/nifi-truststore.jks  - Java truststore containing the public CA certificate
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
profile="$script_dir/../../security/templates/ssl-extensions-x509.cnf"
ca_cert="$security_dir/certificates/root/root-ca.pem"
ca_key="$security_dir/certificates/root/root-ca.key"
output_dir="$security_dir/certificates/nifi"

for input in "$ca_cert" "$ca_key"; do
    if [[ ! -f "$input" || ! -r "$input" || ! -s "$input" ]]; then
        printf 'Missing or unreadable CA file %s. Run create_root_ca_cert.sh first.\n' "$input" >&2
        exit 1
    fi
done

files=(nifi.key nifi.csr nifi.pem nifi.crt nifi.p12 nifi-keystore.jks nifi-truststore.jks)
for file in "${files[@]}"; do
    if [[ -e "$output_dir/$file" || -L "$output_dir/$file" ]]; then
        printf 'Output already exists: %s\n' "$output_dir/$file" >&2
        exit 1
    fi
done

KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:-${NIFI_KEYSTORE_PASSWORD:-}}
TRUSTSTORE_PASSWORD=${TRUSTSTORE_PASSWORD:-${NIFI_TRUSTSTORE_PASSWORD:-}}
# shellcheck source=password_prompt.sh
source "$script_dir/password_prompt.sh"
require_password KEYSTORE_PASSWORD
require_password TRUSTSTORE_PASSWORD

# Build the whole bundle before publishing it. Clean up files written by this
# run if any of the final writes fail.
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

# === Add deployment-specific SANs to the template defaults
names=("${NIFI_UPSTREAM_TLS_NAME:-}" "${NIFI_HEALTHCHECK_HOST:-}")
if [[ -n "${KUBE_NAMESPACE:-}" ]]; then
    names+=("cogstack-nifi-web.${KUBE_NAMESPACE}.svc.${CLUSTER_DOMAIN:-cluster.local}")
fi

{
    cat -- "$profile"
    printf '\n[alt_names]\n'
    index=100
    for name in "${names[@]}"; do
        [[ -n "$name" ]] || continue
        if [[ "$name" =~ ^[0-9]+(\.[0-9]+){3}$ || ( "$name" == *:* && "$name" =~ ^[[:xdigit:]:.]+$ ) ]]; then
            type=IP
        elif [[ "$name" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
            type=DNS
        else
            printf 'Invalid TLS hostname or IP: %s\n' "$name" >&2
            exit 2
        fi
        printf '%s.%d = %s\n' "$type" "$index" "$name"
        index=$((index + 1))
    done
} > "$scratch_dir/leaf.cnf"

# === Generate the key and issue the leaf certificate
openssl req -new -newkey rsa:4096 -nodes -config "$profile" \
    -keyout "$scratch_dir/nifi.key" -out "$scratch_dir/nifi.csr"
serial=$(openssl rand -hex 16)
openssl x509 -req -sha256 -days "$days" -set_serial "0x$serial" \
    -in "$scratch_dir/nifi.csr" -CA "$ca_cert" -CAkey "$ca_key" \
    -extfile "$scratch_dir/leaf.cnf" -extensions v3_leaf -out "$scratch_dir/nifi.pem"
openssl verify -CAfile "$ca_cert" "$scratch_dir/nifi.pem" >/dev/null
openssl x509 -in "$scratch_dir/nifi.pem" -outform DER -out "$scratch_dir/nifi.crt"

# === Build the Java stores
# Include the public CA in the private key's chain and trust it in the truststore.
openssl pkcs12 -export -name nifi -inkey "$scratch_dir/nifi.key" \
    -in "$scratch_dir/nifi.pem" -certfile "$ca_cert" -out "$scratch_dir/nifi.p12" \
    -keypbe AES-256-CBC -certpbe AES-256-CBC -passout env:KEYSTORE_PASSWORD
keytool -importkeystore -noprompt -alias nifi \
    -srckeystore "$scratch_dir/nifi.p12" -srcstoretype PKCS12 -srcstorepass:env KEYSTORE_PASSWORD \
    -destkeystore "$scratch_dir/nifi-keystore.jks" -deststoretype JKS \
    -deststorepass:env KEYSTORE_PASSWORD -destkeypass:env KEYSTORE_PASSWORD
keytool -importcert -noprompt -alias root-ca -file "$ca_cert" \
    -keystore "$scratch_dir/nifi-truststore.jks" -storetype JKS -storepass:env TRUSTSTORE_PASSWORD

# === Publish the bundle
# Noclobber keeps concurrent attempts from overwriting each other's files.
(umask 022; mkdir -p -- "$output_dir")
set -o noclobber
for file in "${files[@]}"; do
    {
        published+=("$output_dir/$file")
        cat -- "$scratch_dir/$file"
    } > "$output_dir/$file"
done
chmod 644 "$output_dir"/nifi.{csr,pem,crt} "$output_dir/nifi-truststore.jks"
printf 'Created NiFi certificates and Java stores under %s\n' "$output_dir"
