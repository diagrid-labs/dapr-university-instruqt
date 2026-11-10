#!/usr/bin/env bash
b_orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5003/secret/orderdb-password)
[ "${b_orderdb##* }" = "403" ] || exit 1
echo "App B is refused orderdb-password."
