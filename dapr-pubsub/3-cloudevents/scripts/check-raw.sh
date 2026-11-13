#!/usr/bin/env bash
set -u
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

# Gate: only when demo 3's shipping answers (app id shipping with an orders-raw subscription).
[ "$(metadata_app_id 3511)" = "shipping" ] || exit 0
raw_type=$(metadata_sub_type 3511 orders-raw)
{ [ -n "$raw_type" ] && [ "$raw_type" != "NONE" ]; } || exit 0

log=$(latest_app_log 3 shipping)
if [ -z "$log" ] || ! grep -q "received raw:" "$log"; then
    echo "No 'shipping received raw:' line yet in the log of shipping. Send an order with the curl command in step 4 (the one for /orders/raw), then run the check again."
    exit 1
fi
echo "Shipping received a raw order."
