#!/usr/bin/env bash
orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5001/secret/orderdb-password)
if [ "${orderdb##* }" = "000" ]; then
    # Gate: when the Demo2-Scoping apps from the previous challenge still answer,
    # check-previous-apps-stopped.sh reports it. Pass here so the learner sees only that hint.
    for port in 5002 5003; do
        [ "$(curl -s -m 10 -o /dev/null -w '%{http_code}' "http://localhost:$port/")" = "000" ] || exit 0
    done
    exit 1
fi
echo "The app answers on port 5001."
