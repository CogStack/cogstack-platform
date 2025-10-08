#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR=$(basename "$PWD")

OUTPUT_DIR_PATH_PREFIX="../"
# If we are in a "scripts" subdirectory that has a parent containing common project markers
if [[ "$CURRENT_DIR" == "scripts" && ( -f ../Makefile || -f ../README.* || -d ../src || -d ../app ) ]]; then
    OUTPUT_DIR_PATH_PREFIX="../"
# If we are in a project root (heuristic: has a scripts/ folder or common project files)
elif [[ -d scripts || -f Makefile || -f README.* || -d src || -d app ]]; then
    OUTPUT_DIR_PATH_PREFIX="./"
fi

curl https://raw.githubusercontent.com/CogStack/CogStack-NiFi/refs/heads/main/deploy/general.env > ${OUTPUT_DIR_PATH_PREFIX}env/general.env
curl https://raw.githubusercontent.com/CogStack/CogStack-NiFi/refs/heads/main/security/certificates/root/root-ca.key > ${OUTPUT_DIR_PATH_PREFIX}security/root-ca.key
curl https://raw.githubusercontent.com/CogStack/CogStack-NiFi/refs/heads/main/security/certificates/root/root-ca.pem > ${OUTPUT_DIR_PATH_PREFIX}security/root-ca.pem