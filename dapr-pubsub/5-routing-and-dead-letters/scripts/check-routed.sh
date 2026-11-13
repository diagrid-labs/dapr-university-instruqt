#!/usr/bin/env bash
set -u
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

# Gate: only when demo 5's shipping answers. Otherwise check-apps-running.sh reports it.
[ "$(metadata_app_id 3511)" = "shipping" ] || exit 0
[ "$(metadata_sub_route 3511 orders)" = "/orders/express" ] || exit 0

# The newest shipping log of demo 5 in any language folder. Java adds a Spring prefix before the
# message, so only the message is matched.
log=$(latest_app_log 5 shipping)
if [ -z "$log" ] || ! grep -q "shipping standard order" "$log"; then
    echo "No 'shipping standard order' line yet in the log of shipping. Send the three orders with the command in step 3, then run the check again."
    exit 1
fi
if ! grep -q "shipping express order" "$log"; then
    echo "No 'shipping express order' line yet in the log of shipping. Send the three orders with the command in step 3, then run the check again."
    exit 1
fi
echo "Shipping routed a standard order and an express order."
