#!/usr/bin/env bash

# =============================================================================================================================
# 🔐 Create Root CA certificate, private key, and keystore/truststore bundle
#
# Usage:
#     ./create_root_ca_cert.sh
#     Set SECURITY_DIR to place the whole bundle under a different directory.
#
# Requires:
#     - Bash, OpenSSL and Java keytool
#     - ROOT_CERTIFICATE_KEYSTORE_PASSWORD in the environment
#     - ../../security/templates/ssl-extensions-x509.cnf relative to this script
#
# Output:
#     Default paths relative to the repository root.
#     deployment/security/certificates/root/root-ca.key             - RSA CA signing key
#     deployment/security/certificates/root/root-ca.p12             - Encrypted PKCS#12 bundle with the CA key and certificate
#     deployment/security/certificates/root/root-ca-keystore.jks    - Java keystore with the CA key and certificate
#     deployment/security/certificates/root/root-ca.pem             - Self-signed X.509 CA certificate in PEM format
#     deployment/security/certificates/root/root-ca.crt             - The same CA certificate in binary DER format
#     deployment/security/certificates/root/root-ca.csr             - Certificate signing request for the CA key and subject
#     deployment/security/certificates/root/root-ca-truststore.jks  - Java truststore containing the public CA certificate
# =============================================================================================================================

set -euo pipefail
umask 077

# === Resolve the profile and output paths
# SECURITY_DIR controls the bundle location. Resolve the checked-in OpenSSL profile
# relative to this script.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_DIR="${SECURITY_DIR:-$SCRIPT_DIR/../../security}"
EXT_FILE="$SCRIPT_DIR/../../security/templates/ssl-extensions-x509.cnf"
CA_NAME=root-ca
ROOT_DIR="$SECURITY_DIR/certificates/root"

KEY_FILE="$ROOT_DIR/$CA_NAME.key"
P12_FILE="$ROOT_DIR/$CA_NAME.p12"
JKS_FILE="$ROOT_DIR/$CA_NAME-keystore.jks"
PEM_FILE="$ROOT_DIR/$CA_NAME.pem"
CRT_FILE="$ROOT_DIR/$CA_NAME.crt"
CSR_FILE="$ROOT_DIR/$CA_NAME.csr"
TRUSTSTORE_FILE="$ROOT_DIR/$CA_NAME-truststore.jks"

# OpenSSL and keytool read the store password from the environment.
: "${ROOT_CERTIFICATE_KEYSTORE_PASSWORD:?Set ROOT_CERTIFICATE_KEYSTORE_PASSWORD}"
export ROOT_CERTIFICATE_KEYSTORE_PASSWORD

# === Protect existing CA material
# Replacing a CA invalidates trust for certificates issued under the old key.
for output in "$KEY_FILE" "$PEM_FILE" "$CRT_FILE" "$CSR_FILE" "$P12_FILE" "$JKS_FILE" "$TRUSTSTORE_FILE"; do
    if [[ -e "$output" || -L "$output" ]]; then
        printf 'Output already exists: %s\n' "$output" >&2
        exit 1
    fi
done

# Build the entire bundle in a private temporary directory. If publication fails,
# remove the files written by this run and clean up the temporary directory.
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

publish() {
    {
        published+=("$2")
        cat "$1"
    } > "$2"
}

# === Generate the RSA signing key and self-signed CA certificate
# The v3_ca profile authorizes the 4096-bit key to sign certificates and revocation
# lists. Issue the PEM certificate for 1,460 days, then derive the binary DER copy.
openssl req -x509 \
    -newkey rsa:4096 -nodes \
    -keyout "$scratch_dir/ca.key" \
    -sha256 \
    -days 1460 \
    -out "$scratch_dir/ca.pem" \
    -extensions v3_ca \
    -config "$EXT_FILE"
openssl x509 -in "$scratch_dir/ca.pem" -out "$scratch_dir/ca.crt" -outform DER

# === Write the signing request
# The CSR records the CA subject and public key and is signed with the CA key.
openssl req -new -key "$scratch_dir/ca.key" -out "$scratch_dir/ca.csr" -config "$EXT_FILE"

# === Create the encrypted PKCS#12 bundle
# Use explicit AES encryption so OpenSSL and LibreSSL produce compatible bundles.
openssl pkcs12 -export \
    -in "$scratch_dir/ca.pem" \
    -inkey "$scratch_dir/ca.key" \
    -out "$scratch_dir/ca.p12" \
    -name "$CA_NAME" \
    -keypbe AES-256-CBC -certpbe AES-256-CBC \
    -passout env:ROOT_CERTIFICATE_KEYSTORE_PASSWORD

# === Create the Java keystore
# Import the private key entry and its certificate under the CA name.
keytool -importkeystore \
    -destkeystore "$scratch_dir/keystore.jks" \
    -deststoretype JKS \
    -srckeystore "$scratch_dir/ca.p12" \
    -srcstoretype PKCS12 \
    -alias "$CA_NAME" \
    -srcstorepass:env ROOT_CERTIFICATE_KEYSTORE_PASSWORD \
    -deststorepass:env ROOT_CERTIFICATE_KEYSTORE_PASSWORD \
    -noprompt

# === Create the Java truststore
# Import the public CA certificate as the trust anchor for Java consumers.
keytool -importcert \
    -file "$scratch_dir/ca.pem" \
    -alias "$CA_NAME" \
    -keystore "$scratch_dir/truststore.jks" \
    -storetype JKS \
    -storepass:env ROOT_CERTIFICATE_KEYSTORE_PASSWORD \
    -noprompt

# === Publish the bundle
# Private files use mode 0600 and public files use mode 0644. Noclobber protects
# files that appear after the initial check, including those from a concurrent run.
(umask 022; mkdir -p -- "$ROOT_DIR")
set -o noclobber
publish "$scratch_dir/ca.key" "$KEY_FILE"
publish "$scratch_dir/ca.p12" "$P12_FILE"
publish "$scratch_dir/keystore.jks" "$JKS_FILE"
umask 022
publish "$scratch_dir/ca.pem" "$PEM_FILE"
publish "$scratch_dir/ca.crt" "$CRT_FILE"
publish "$scratch_dir/ca.csr" "$CSR_FILE"
publish "$scratch_dir/truststore.jks" "$TRUSTSTORE_FILE"

printf 'Created root CA certificate %s and signing key %s\n' "$PEM_FILE" "$KEY_FILE"

