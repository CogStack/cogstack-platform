#!/usr/bin/env bash

package_is_installed() {
    local distribution="$1" package="$2"

    case "$distribution" in
        debian|ubuntu)
            [ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null)" = "install ok installed" ]
            ;;
        redhat) rpm -q "$package" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

install_missing_packages() {
    local distribution="$1" package
    local missing_packages=()
    shift

    for package in "$@"; do
        if ! package_is_installed "$distribution" "$package"; then
            missing_packages+=("$package")
        fi
    done

    if [ "${#missing_packages[@]}" -eq 0 ]; then
        echo "All requested system packages are already installed."
        return 0
    fi

    echo "Installing missing system packages: ${missing_packages[*]}"
    case "$distribution" in
        debian|ubuntu)
            sudo apt-get update -y
            sudo apt-get install -y "${missing_packages[@]}"
            ;;
        redhat) sudo yum install -y "${missing_packages[@]}" ;;
        *) echo "No instructions given for distribution: $distribution" >&2; return 1 ;;
    esac
}

apt_repository_exists() {
    local name="$1" uri="$2" source_file

    # Preserve existing files, including the newer deb822 .sources format.
    if [ -e "/etc/apt/sources.list.d/${name}.list" ] || [ -e "/etc/apt/sources.list.d/${name}.sources" ]; then
        return 0
    fi

    # The same repository may already be configured under a different filename.
    for source_file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        if [ -f "$source_file" ] && \
            grep -E '^[[:space:]]*(deb(-src)?[[:space:]]|URIs:)' "$source_file" | grep -F -- "$uri" >/dev/null; then
            return 0
        fi
    done
    return 1
}
