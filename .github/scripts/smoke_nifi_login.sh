#!/usr/bin/env bash
set -euo pipefail

api="${1%/}/nifi-api"
request=(curl -fsS --noproxy '*' --cacert "$SECURITY_DIR/certificates/root/root-ca.pem" --max-time 10)
token=$("${request[@]}" --retry 30 --retry-all-errors --retry-delay 10 --retry-max-time 300 \
    --data-urlencode "username=$SINGLE_USER_CREDENTIALS_USERNAME" \
    --data-urlencode "password=$SINGLE_USER_CREDENTIALS_PASSWORD" "$api/access/token")
[[ -n "$token" ]]
"${request[@]}" --header "Authorization: Bearer $token" "$api/flow/current-user" |
    jq -e --arg user "$SINGLE_USER_CREDENTIALS_USERNAME" '.identity == $user and .anonymous == false'
