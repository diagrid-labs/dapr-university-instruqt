#!/usr/bin/env bash
# Page 3 check: the Dev Dashboard that the AppHost runs as the dev-dashboard resource answers on
# port 9090. It binds 0.0.0.0 and only accepts a loopback Host header, as the Dev Dashboard tab sends.
# Read-only. DEV_DASHBOARD_URL overrides the address (pytest sets it); the Host header stays.
set -u
url="${DEV_DASHBOARD_URL:-http://localhost:9090}"
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H 'Host: localhost:9090' \
    "$url/api/workflows" 2>/dev/null)"
case "$code" in
    000|"")
        echo "The Dev Dashboard does not answer on $url."
        exit 1
        ;;
    2*) ;;
    *)
        echo "The Dev Dashboard answers on $url with HTTP $code."
        exit 1
        ;;
esac
echo "The Dev Dashboard answers on $url."
