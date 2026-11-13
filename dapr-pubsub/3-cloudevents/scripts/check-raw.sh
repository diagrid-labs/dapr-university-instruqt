#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

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
