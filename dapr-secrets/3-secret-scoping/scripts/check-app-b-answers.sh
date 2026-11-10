#!/usr/bin/env bash
b_orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5003/secret/orderdb-password)
[ "${b_orderdb##* }" != "000" ] || exit 1
echo "App B answers on port 5003."
