#!/usr/bin/env bash
# Source selected configuration without changing the caller's shell options.

_cogstack_load_environment() {
  local loader_path
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    # The expression is evaluated only by zsh; Bash uses BASH_SOURCE below.
    eval 'loader_path=${(%):-%x}'
  else
    loader_path="${BASH_SOURCE[0]}"
  fi
  local deploy_path
  deploy_path="$(cd "$(dirname "$loader_path")" && pwd)" || return 1
  local relative_files=(
    ../env/general.env
    ../env/nifi.env
    ../env/network_settings.env
  )
  local relative_file selected_file variable_name file_name
  local restore_allexport=1
  case "$-" in *a*) restore_allexport=0 ;; esac
  set -a
  for relative_file in "${relative_files[@]}"; do
    file_name="${relative_file##*/}"
    variable_name="COGSTACK_$(printf '%s' "${file_name%.env}" | tr '[:lower:]' '[:upper:]')_ENV_FILE"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      eval 'selected_file=${(P)variable_name:-}'
    else
      selected_file="${!variable_name:-}"
    fi
    selected_file="${selected_file:-$deploy_path/$relative_file}"
    export "$variable_name=$selected_file"
    # shellcheck disable=SC1090
    source "$selected_file" || {
      echo "ERROR: Failed to load configuration: $selected_file" >&2
      if [[ "$restore_allexport" == 1 ]]; then set +a; fi
      return 1
    }
  done

  # Local image builds match bind-mounted configuration/certificate ownership.
  # Published images retain their Dockerfile's default non-root UID/GID.
  export COGSTACK_LOCAL_UID="${COGSTACK_LOCAL_UID:-$(id -u)}"
  export COGSTACK_LOCAL_GID="${COGSTACK_LOCAL_GID:-$(id -g)}"
  if [[ "$COGSTACK_LOCAL_UID" == 0 ]]; then export COGSTACK_LOCAL_UID=1000; fi
  if [[ "$COGSTACK_LOCAL_GID" == 0 ]]; then export COGSTACK_LOCAL_GID=1000; fi
  export DOLLAR='$'
  if [[ "$restore_allexport" == 1 ]]; then set +a; fi
  echo "Configuration loaded."
}

if _cogstack_load_environment; then
  unset -f _cogstack_load_environment
else
  unset -f _cogstack_load_environment
  # Also support executing the loader instead of sourcing it.
  # shellcheck disable=SC2317
  return 1 2>/dev/null || exit 1
fi
