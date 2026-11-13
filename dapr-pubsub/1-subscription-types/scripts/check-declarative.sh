#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

type=$(metadata_sub_type 3511 orders)
# Gate: when shipping's sidecar does not answer, check-apps-running.sh reports it. Pass here so
# the learner sees only that hint, not a second, misleading one.
[ -n "$type" ] || exit 0
if [ "$type" != "DECLARATIVE" ]; then
    echo "Shipping's subscription to the orders topic is '$type', not DECLARATIVE."
    exit 1
fi
echo "Shipping's subscription to orders is DECLARATIVE."
