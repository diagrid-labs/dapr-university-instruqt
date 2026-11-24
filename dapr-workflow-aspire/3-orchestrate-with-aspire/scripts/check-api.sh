#!/usr/bin/env bash
# Page 3 check: the engineering app answers on port 5411, which means `aspire run` runs it.
# It asks the status endpoint for an instance that does not exist: 404 means the app and its Dapr
# sidecar answer; a 5xx means the app runs but cannot reach its sidecar.
# Read-only. ENGINEERING_URL overrides the app's address (pytest sets it).
set -u
url="${ENGINEERING_URL:-http://localhost:5411}"
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url/status/orchestrate-check" 2>/dev/null)"
case "$code" in
    000|"")
        echo "The engineering app does not answer on $url."
        exit 1
        ;;
    5*)
        echo "The engineering app answers on $url, but its status endpoint returned HTTP $code."
        exit 1
        ;;
esac
echo "The engineering app answers on $url (HTTP $code)."
