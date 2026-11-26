#!/usr/bin/env bash

require_password() {
    local name=$1 password

    if [[ -n ${!name:-} ]]; then
        export "${name?}"
        return
    fi

    if [[ ! -t 0 ]]; then
        printf 'Set %s in the environment or run this command in a terminal.\n' "$name" >&2
        return 1
    fi

    if ! IFS= read -r -s -p "Enter $name: " password || [[ -z "$password" ]]; then
        printf '\nSet %s to a nonempty password.\n' "$name" >&2
        return 1
    fi

    printf '\n' >&2
    export "$name=$password"
}

bcrypt_entry() {
    local user=$1 password=$2 LC_ALL=C
    if [[ "$password" == *[$'\r\n']* || ${#password} -gt 72 ]]; then
        printf 'The password for %s must fit on one line and be at most 72 bytes.\n' "$user" >&2
        return 1
    fi
    printf '%s\n' "$password" | htpasswd -nBi -C 10 -- "$user"
}
