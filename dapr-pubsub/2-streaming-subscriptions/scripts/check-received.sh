#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

# Gate: when the warehouse's sidecar does not answer, check-apps-running.sh reports it.
[ -n "$(metadata_app_id 3511)" ] || exit 0

# The newest warehouse log of demo 2 in any language folder: the learner may have used another
# language on another page. The line carries the app name, so a Java log with a Spring prefix
# still matches.
log=$(latest_app_log 2 warehouse)
if [ -z "$log" ] || ! grep -q "warehouse received order" "$log"; then
    echo "No 'warehouse received order' line yet in the log of the warehouse. Send an order with the curl command in step 4, then run the check again."
    exit 1
fi
echo "The warehouse received an order."
