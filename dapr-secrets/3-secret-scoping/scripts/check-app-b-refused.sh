#!/usr/bin/env bash
b_orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5003/secret/orderdb-password)
# Gate: when app B does not answer, check-app-b-answers.sh reports it. Pass here so the learner
# sees only that hint, not a second, misleading one.
[ "${b_orderdb##* }" != "000" ] || exit 0
[ "${b_orderdb##* }" = "403" ] || exit 1
echo "App B is refused orderdb-password."
