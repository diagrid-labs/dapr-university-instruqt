#!/usr/bin/env bash
set -u
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

# Gate: only when demo 4's shipping answers. Otherwise check-apps-running.sh reports it.
[ "$(metadata_app_id 3511)" = "shipping" ] || exit 0
[ "$(metadata_sub_route 3511 orders)" = "/orders/bulk" ] || exit 0

# Post the two-entry bulk body of step 5 straight to the app: e1 is a complete CloudEvent, e2 is not.
body='{"entries":[{"entryId":"e1","event":{"data":{"orderId":"o-check-4001","item":"coffee-beans","quantity":1,"priority":"standard"},"datacontenttype":"application/json","id":"e1-event","source":"check","specversion":"1.0","type":"com.dapr.event.sent"},"contentType":"application/cloudevents+json"},{"entryId":"e2","event":{"nothing":"here"},"contentType":"application/cloudevents+json"}],"topic":"orders"}'
answer=$(curl -s -m 10 -X POST http://localhost:5102/orders/bulk -H 'Content-Type: application/json' -d "$body")
# Compare parsed JSON so field order and spacing cannot matter.
if ! printf '%s' "$answer" | python3 -c '
import json, sys
try:
    st = {s["entryId"]: s["status"] for s in json.load(sys.stdin)["statuses"]}
except Exception:
    sys.exit(1)
sys.exit(0 if st.get("e1") == "SUCCESS" and st.get("e2") == "DROP" else 1)' 2>/dev/null; then
    echo "Shipping did not answer SUCCESS for entry e1 and DROP for entry e2 (it answered: ${answer:-nothing}). Check the Dapr CLI window for errors from shipping, post the body from step 5 again and run the check again."
    exit 1
fi
echo "Shipping answered SUCCESS for e1 and DROP for e2."
