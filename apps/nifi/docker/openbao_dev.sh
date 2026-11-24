#!/usr/bin/env bash
# Source from the NiFi dev Make targets.

_nifi_dev_openbao_request() {
    : "${NIFI_DEV_OPENBAO_ADDR:?Set NIFI_DEV_OPENBAO_ADDR}" "${BAO_TOKEN:?Export BAO_TOKEN in your shell}"
    curl --noproxy '*' --fail --silent --show-error --connect-timeout 3 --max-time 10 \
        --header @<(printf 'X-Vault-Token: %s\n' "$BAO_TOKEN") \
        "$@" "${NIFI_DEV_OPENBAO_ADDR%/}/v1/secret/data/nifi/dev"
}

nifi_openbao_dev() {
    local keys=(SINGLE_USER_CREDENTIALS_USERNAME SINGLE_USER_CREDENTIALS_PASSWORD
        KEYSTORE_PASSWORD TRUSTSTORE_PASSWORD)
    local secret key value

    if [[ $1 == seed ]]; then
        (
            unset "${keys[@]}"
            set -a
            # shellcheck disable=SC1090
            source "$2" || exit
            set +a
            secret=$(jq -en --args '
                $ARGS.positional | map({(.): env[.]}) | add |
                if all(.[]; type == "string" and length > 0)
                then {options: {cas: 0}, data: .}
                else error("Set all four NiFi demo credentials before seeding OpenBao")
                end
            ' "${keys[@]}") || exit
            printf '%s' "$secret" | _nifi_dev_openbao_request \
                --header 'Content-Type: application/json' --data-binary @- >/dev/null
        )
        return
    fi

    secret=$(_nifi_dev_openbao_request) || {
        printf 'Could not read OpenBao secret/nifi/dev. Check the address, token, and seed entry.\n' >&2
        return 1
    }
    for key in "${keys[@]}"; do
        value=$(jq -er --arg key "$key" '.data.data[$key] | select(type == "string" and length > 0)' <<< "$secret") || {
            printf 'OpenBao secret/nifi/dev is missing %s.\n' "$key" >&2
            return 1
        }
        export "$key=$value"
    done
}
