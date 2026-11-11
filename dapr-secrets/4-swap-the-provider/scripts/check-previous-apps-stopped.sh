#!/usr/bin/env bash
# In a 2.0 lab the Dapr CLI window keeps running whatever the learner started on the previous
# page. When the swap app does not answer on 5001 but App A or App B from Demo2-Scoping still
# answers (5002/5003), fail here with that specific hint. In every other case pass, so
# check-app-answers.sh gives the generic one.
status() { curl -s -m 10 -o /dev/null -w '%{http_code}' "$1"; }
[ "$(status http://localhost:5001/secret/orderdb-password)" = "000" ] || exit 0
if [ "$(status http://localhost:5002/)" != "000" ] || [ "$(status http://localhost:5003/)" != "000" ]; then
    exit 1
fi
echo "No apps from the previous lab are blocking the swap."
