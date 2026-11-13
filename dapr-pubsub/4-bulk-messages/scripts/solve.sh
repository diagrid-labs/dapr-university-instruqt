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

# 2. Start demo 4 in .NET in the background. The check only needs the apps to answer and log, so it
# does not matter which language the learner used.
start_demo_detached "$PUBSUB/dotnet/Demo4-Bulk" /tmp/dapr-pubsub-demo4.log

# 3. Wait until both apps answer and shipping routes orders to /orders/bulk.
for _ in $(seq 1 120); do
    if port_answers 5101 && port_answers 5102 && [ "$(metadata_sub_route 3511 orders)" = "/orders/bulk" ]; then
        break
    fi
    sleep 2
done

# 4. Publish 25 orders in one call, retried until order-api accepts it.
run_id="solve-$(date +%s)"
for _ in $(seq 1 30); do
    curl -s -m 20 -X POST "http://localhost:5101/orders/bulk?count=25&prefix=$run_id" | grep -q '"sent": *25' && break
    sleep 2
done

# 5. Wait until shipping has logged a batch with one of this run's orders.
for _ in $(seq 1 60); do
    log=$(latest_app_log 4 shipping)
    if [ -n "$log" ] && grep "received batch of" "$log" | grep -q "$run_id-"; then
        echo "Started demo 4 in .NET and published 25 orders ($run_id-1 to $run_id-25): shipping logged them in batches (whichever language you used before)."
        exit 0
    fi
    sleep 2
done
echo "The orders did not reach shipping within 2 minutes. See /tmp/dapr-pubsub-demo4.log" >&2
exit 1
