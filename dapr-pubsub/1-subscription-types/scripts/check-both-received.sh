#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

# Gate: when an app does not answer, check-apps-running.sh reports it. Pass here so the learner
# sees only that hint, not a second, misleading one.
port_answers 5102 || exit 0
port_answers 5103 || exit 0

# The newest log of each app in any language folder: the learner may have used another language
# on another page. Lines carry the app name, so a Java log with a Spring prefix still matches.
missing=""
for app in shipping invoicing; do
    log=$(latest_app_log 1 "$app")
    if [ -z "$log" ] || ! grep -q "$app received order" "$log"; then
        missing="$missing $app"
    fi
done
if [ -n "$missing" ]; then
    echo "No 'received order' line yet in the log of:$missing. Send an order with the curl command in step 4, then run the check again."
    exit 1
fi
echo "Shipping and invoicing both received an order."
