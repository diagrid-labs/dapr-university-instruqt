#!/usr/bin/env bash
orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5001/secret/orderdb-password)
[ "${orderdb##* }" = "200" ] || exit 1
echo "The app reads orderdb-password."
