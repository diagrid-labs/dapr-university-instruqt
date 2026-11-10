#!/usr/bin/env bash
# curl prints the body, a space and the HTTP status (000 when nothing answers).
a_orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5002/secret/orderdb-password)
[ "${a_orderdb##* }" = "200" ] || exit 1
echo "App A reads orderdb-password."
