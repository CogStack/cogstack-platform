#!/usr/bin/env bash

require_password() {
    local name=$1 password

    if [[ -n ${!name:-} ]]; then
        export "${name?}"
        return
    fi

    if [[ ! -t 0 ]]; then
        printf 'Set %s in the environment or run this generator in a terminal.\n' "$name" >&2
        return 1
    fi

    if ! IFS= read -r -s -p "Enter $name: " password || [[ -z "$password" ]]; then
        printf '\nSet %s to a nonempty password.\n' "$name" >&2
        return 1
    fi

    printf '\n' >&2
    export "$name=$password"
}
