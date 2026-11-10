#!/usr/bin/env bash
orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5001/secret/orderdb-password)
# Gate: when the app does not answer, check-app-answers.sh reports it. Pass here so the learner
# sees only that hint, not a second, misleading one.
[ "${orderdb##* }" != "000" ] || exit 0
[ "${orderdb##* }" = "200" ] || exit 1
echo "The app reads orderdb-password."
