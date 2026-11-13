#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

# The first condition of the page. When it fails, the others are gated, so this message is the only
# hint the learner gets. Demos 1, 3, 4 and 5 all run `shipping` on 3511, so demo 3 is told apart by
# its own orders-raw subscription in the metadata of that sidecar.
shipping_id=$(metadata_app_id 3511)
if [ -n "$shipping_id" ]; then
    raw_type=$(metadata_sub_type 3511 orders-raw)
    if [ "$shipping_id" != "shipping" ] || [ "$raw_type" = "NONE" ]; then
        echo "The sidecar on port 3511 belongs to '$shipping_id' and has no orders-raw subscription, so it is not this page's demo. Another page's demo is still running. Press Ctrl+C in the Dapr CLI window to stop it, then start this page's demo (Demo3-CloudEvents or demo3-cloud-events)."
        exit 1
    fi
fi
missing=""
port_answers 5101 || missing="$missing 5101 (order-api)"
port_answers 5102 || missing="$missing 5102 (shipping)"
[ -n "$shipping_id" ] || missing="$missing 3511 (the sidecar of shipping)"
if [ -n "$missing" ]; then
    echo "Nothing answers on port(s)$missing. Is 'dapr run -f .' running in this page's demo folder (Demo3-CloudEvents or demo3-cloud-events)? If another page's demo is still running, press Ctrl+C in the Dapr CLI window first."
    exit 1
fi
echo "order-api and shipping answer on ports 5101 and 5102."
