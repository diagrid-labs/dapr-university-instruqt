#!/usr/bin/env bash
b_payments=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5003/secret/payments-api-key)
# Gate: when app B does not answer, check-app-b-answers.sh reports it. Pass here so the learner
# sees only that hint, not a second, misleading one.
[ "${b_payments##* }" != "000" ] || exit 0
[ "${b_payments##* }" = "200" ] || exit 1
echo "App B reads payments-api-key."
