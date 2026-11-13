#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

# Gate: when invoicing's sidecar does not answer, or another page's demo holds port 3511,
# check-apps-running.sh reports it. Pass here so the learner sees only that hint, not a second,
# misleading one.
[ "$(metadata_app_id 3511)" = "shipping" ] || exit 0
[ "$(metadata_app_id 3512)" = "invoicing" ] || exit 0
type=$(metadata_sub_type 3512 orders)
[ -n "$type" ] || exit 0
if [ "$type" != "PROGRAMMATIC" ]; then
    echo "Invoicing's subscription to the orders topic is '$type', not PROGRAMMATIC."
    exit 1
fi
echo "Invoicing's subscription to orders is PROGRAMMATIC."
