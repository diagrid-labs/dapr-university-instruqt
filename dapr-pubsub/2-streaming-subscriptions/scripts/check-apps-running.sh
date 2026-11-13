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
# The warehouse has no app port, so the check asks its sidecar (3511) instead of an app port.
warehouse_id=$(metadata_app_id 3511)
if [ -n "$warehouse_id" ] && [ "$warehouse_id" != "warehouse" ]; then
    echo "The sidecar on port 3511 belongs to '$warehouse_id', not 'warehouse'. Another page's demo is still running. Press Ctrl+C in the Dapr CLI window to stop it (if Skip or Solve started it, run the stop command under 'Before you start' instead), then start this page's demo."
    exit 1
fi
missing=""
port_answers 5101 || missing="$missing 5101 (order-api)"
[ -n "$warehouse_id" ] || missing="$missing 3511 (the sidecar of warehouse)"
if [ -n "$missing" ]; then
    echo "Nothing answers on port(s)$missing. Is 'dapr run -f .' running in this page's demo folder (Demo2-Streaming or demo2-streaming)? If another page's demo is still running, press Ctrl+C in the Dapr CLI window first."
    exit 1
fi
echo "order-api answers on port 5101 and the sidecar of warehouse on port 3511."
