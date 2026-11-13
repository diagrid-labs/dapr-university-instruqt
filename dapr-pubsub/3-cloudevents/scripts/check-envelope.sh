#!/usr/bin/env bash
set -u
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

# Gate: only when demo 3's shipping answers (app id shipping with an orders-raw subscription).
# Otherwise check-apps-running.sh reports it, and a second hint would mislead.
[ "$(metadata_app_id 3511)" = "shipping" ] || exit 0
raw_type=$(metadata_sub_type 3511 orders-raw)
{ [ -n "$raw_type" ] && [ "$raw_type" != "NONE" ]; } || exit 0

# The newest shipping log of demo 3 in any language folder. The learner may have used another
# language on another page, and Java adds a Spring prefix before the message.
log=$(latest_app_log 3 shipping)
if [ -z "$log" ] || ! grep -q "received with envelope" "$log"; then
    echo "No 'shipping received with envelope' line yet in the log of shipping. Send an order with the first curl command in step 3, then run the check again."
    exit 1
fi
if ! grep -q "parsed CloudEvent" "$log"; then
    echo "Shipping logged the envelope but no 'shipping parsed CloudEvent' line. Look at the Dapr CLI window for errors from shipping, send the order from step 3 again and run the check again."
    exit 1
fi
echo "Shipping received an order with its CloudEvent envelope and parsed it."
