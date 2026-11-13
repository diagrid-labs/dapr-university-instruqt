#!/usr/bin/env bash
set -u
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

# Gate: only when demo 5's shipping answers. Otherwise check-apps-running.sh reports it.
[ "$(metadata_app_id 3511)" = "shipping" ] || exit 0
[ "$(metadata_sub_route 3511 orders)" = "/orders/express" ] || exit 0

# Only the poison order is dead-lettered, so any 'dead-lettered order' line is its arrival on
# orders-dead. It shows up about 3 seconds after the order was published (3 retries, 1 second apart).
log=$(latest_app_log 5 shipping)
if [ -z "$log" ] || ! grep -q "shipping dead-lettered order" "$log"; then
    echo "No 'shipping dead-lettered order' line yet in the log of shipping. Send the three orders with the command in step 3, wait a few seconds for the retries, then run the check again."
    exit 1
fi
echo "Shipping received a dead-lettered order."
