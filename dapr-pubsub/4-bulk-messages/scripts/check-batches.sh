#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

# Gate: only when demo 4's shipping answers. Otherwise check-apps-running.sh reports it.
[ "$(metadata_app_id 3511)" = "shipping" ] || exit 0
[ "$(metadata_sub_route 3511 orders)" = "/orders/bulk" ] || exit 0

# The newest shipping log of demo 4 in any language folder. Java adds a Spring prefix before the
# message. The batch sizes are not checked: they depend on timing.
log=$(latest_app_log 4 shipping)
if [ -z "$log" ] || ! grep -q "received batch of" "$log"; then
    echo "No 'shipping received batch of' line yet in the log of shipping. Publish the orders with the curl command in step 3, then run the check again."
    exit 1
fi
echo "Shipping received orders in batches."
