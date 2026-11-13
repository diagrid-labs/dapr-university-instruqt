#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

# The first condition of the page. When it fails, the others are gated, so this message is the only
# hint the learner gets: it also covers another page's demo that is still running on these ports.
missing=""
for port in 5101 5102 5103; do
    port_answers "$port" || missing="$missing $port"
done

# Shipping's sidecar is on 3511 in demo 1, but another demo can hold the port with another app.
shipping_id=$(metadata_app_id 3511)
if [ -n "$shipping_id" ] && [ "$shipping_id" != "shipping" ]; then
    echo "The sidecar on port 3511 belongs to '$shipping_id', not 'shipping'. Another page's demo is still running. Press Ctrl+C in the Dapr CLI window to stop it, then start this page's demo."
    exit 1
fi
if [ -n "$missing" ]; then
    echo "Nothing answers on port(s)$missing. Is 'dapr run -f .' running in this page's demo folder? If another page's demo is still running, press Ctrl+C in the Dapr CLI window first."
    exit 1
fi
echo "order-api, shipping and invoicing answer on ports 5101, 5102 and 5103."
