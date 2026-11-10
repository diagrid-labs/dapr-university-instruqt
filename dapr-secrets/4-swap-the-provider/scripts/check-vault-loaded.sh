#!/usr/bin/env bash
# The sidecar lists every loaded component and its type. This is the line for `secretstore`.
store=$(curl -s -m 10 http://localhost:3500/v1.0/metadata | grep -o '"name":"secretstore","type":"[^"]*"' || true)
[ "$store" = '"name":"secretstore","type":"secretstores.hashicorp.vault"' ] || exit 1
echo "Dapr loaded the Vault secret store."
