#!/usr/bin/env bash
# Gate: when the app does not answer, check-app-answers.sh reports it. Pass here so the learner
# sees only that hint, not a second, misleading one. The same goes for an unreachable sidecar.
status=$(curl -s -m 10 -o /dev/null -w '%{http_code}' http://localhost:5001/secret/orderdb-password)
[ "$status" != "000" ] || exit 0
metadata=$(curl -s -m 10 http://localhost:3500/v1.0/metadata || true)
[ -n "$metadata" ] || exit 0
# The sidecar lists every loaded component and its type. This is the line for `secretstore`.
store=$(echo "$metadata" | grep -o '"name":"secretstore","type":"[^"]*"' || true)
[ "$store" = '"name":"secretstore","type":"secretstores.hashicorp.vault"' ] || exit 1
echo "Dapr loaded the Vault secret store."
