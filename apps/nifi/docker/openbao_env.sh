#!/usr/bin/env bash

# Read NiFi's runtime credentials and keystore passwords from OpenBao's
# secret/nifi KV v2 entry, then export them for the Compose startup command.
nifi_openbao_env() {
    : "${BAO_TOKEN:?Export BAO_TOKEN in your shell}"
    local secret key value

    # Trust the OpenBao server with BAO_CACERT when using a private CA.
    if [[ -n ${BAO_CACERT:-} ]]; then set -- --cacert "$BAO_CACERT"; fi

    # Keep the token out of curl's command-line arguments and require HTTPS.
    secret=$(curl --proto '=https' --noproxy '*' --fail --silent --show-error \
        --connect-timeout 3 --max-time 10 --header @<(printf 'X-Vault-Token: %s\n' "$BAO_TOKEN") \
        "$@" "${NIFI_OPENBAO_ADDR%/}/v1/secret/data/nifi") || return

    # Fail before Compose starts if any required value is absent or empty.
    for key in SINGLE_USER_CREDENTIALS_USERNAME SINGLE_USER_CREDENTIALS_PASSWORD KEYSTORE_PASSWORD TRUSTSTORE_PASSWORD; do
        value=$(jq -er --arg key "$key" '.data.data[$key] | strings | select(length > 0)' <<< "$secret") || {
            printf 'OpenBao secret/nifi is missing %s.\n' "$key" >&2
            return 1
        }
        export "$key=$value"
    done
}
