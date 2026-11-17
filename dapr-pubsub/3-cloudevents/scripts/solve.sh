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

# 2. Start demo 3 in .NET in the background. The check only needs the apps to answer and log, so it
# does not matter which language the learner used.
start_demo_detached "$PUBSUB/dotnet/Demo3-CloudEvents" /tmp/dapr-pubsub-demo3.log

# 3. Wait until both apps answer and shipping has loaded the orders-raw subscription.
for _ in $(seq 1 120); do
    if port_answers 5101 && port_answers 5102 && [ "$(metadata_sub_type 3511 orders-raw)" = "DECLARATIVE" ]; then
        break
    fi
    sleep 2
done

# 4. One normal and one raw order, retried until order-api accepts them.
run_id="solve-$(date +%s)"
post_order() {
    for _ in $(seq 1 30); do
        curl -s -m 10 -X POST "http://localhost:5101/$1" -H 'Content-Type: application/json' \
            -d "{\"orderId\":\"$2\",\"item\":\"coffee-beans\",\"quantity\":1,\"priority\":\"standard\"}" \
            | grep -q "$2" && return 0
        sleep 2
    done
    return 1
}
post_order orders "$run_id-1"
post_order orders/raw "$run_id-2"

# 5. Wait until shipping has logged the envelope, the parsed event and the raw body.
for _ in $(seq 1 60); do
    log=$(latest_app_log 3 shipping)
    if [ -n "$log" ] && grep -q "received with envelope: .*$run_id-1" "$log" \
        && grep -q "parsed CloudEvent" "$log" && grep -q "received raw: .*$run_id-2" "$log"; then
        echo "Started demo 3 in .NET and sent $run_id-1 and $run_id-2: shipping logged the envelope and the raw body (whichever language you used before)."
        exit 0
    fi
    sleep 2
done
echo "The orders did not reach shipping within 2 minutes. See /tmp/dapr-pubsub-demo3.log" >&2
exit 1
