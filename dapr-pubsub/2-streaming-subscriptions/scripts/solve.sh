#!/usr/bin/env bash
set -e
export PATH="${HOME:-/root}/.local/bin:$PATH:/usr/local/bin"
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-${HOME:-/root}/ai-agent-tracks-instruqt}"
PUBSUB="$TRACKS_SRC_DIR/pubsub"
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

# 1. Stop whatever the learner has running (any demo, any language) so the ports are free again.
stop_all_demos

# 2. Start demo 2 in .NET in the background. The check only needs the apps to answer and log, so it
# does not matter which language the learner used.
start_demo_detached "$PUBSUB/dotnet/Demo2-Streaming" /tmp/dapr-pubsub-demo2.log

# 3. Wait until order-api answers and the warehouse's stream is open, then send one order.
for _ in $(seq 1 120); do
    if port_answers 5101 && [ "$(metadata_sub_type 3511 orders)" = "STREAMING" ]; then
        break
    fi
    sleep 2
done
order="solve-$(date +%s)"
for _ in $(seq 1 30); do
    curl -s -m 10 -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
        -d "{\"orderId\":\"$order\",\"item\":\"coffee-beans\",\"quantity\":1,\"priority\":\"standard\"}" \
        | grep -q "$order" && break
    sleep 2
done

# 4. Wait until the warehouse has logged it.
for _ in $(seq 1 60); do
    log=$(latest_app_log 2 warehouse)
    if [ -n "$log" ] && grep -q "warehouse received order $order" "$log"; then
        echo "Started demo 2 in .NET and sent order $order: the warehouse received it over the stream (whichever language you used before)."
        exit 0
    fi
    sleep 2
done
echo "The order did not reach the warehouse within 2 minutes. See /tmp/dapr-pubsub-demo2.log" >&2
exit 1
