#!/usr/bin/env bash
b_payments=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5003/secret/payments-api-key)
[ "${b_payments##* }" = "200" ] || exit 1
echo "App B reads payments-api-key."
