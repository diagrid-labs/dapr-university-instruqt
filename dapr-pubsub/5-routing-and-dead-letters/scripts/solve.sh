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

# 2. Start demo 5 in .NET in the background. The check only needs the apps to answer and log, so it
# does not matter which language the learner used.
start_demo_detached "$PUBSUB/dotnet/Demo5-RoutingDeadLetter" /tmp/dapr-pubsub-demo5.log

# 3. Wait until both apps answer and shipping routes express orders to /orders/express.
for _ in $(seq 1 120); do
    if port_answers 5101 && port_answers 5102 && [ "$(metadata_sub_route 3511 orders)" = "/orders/express" ]; then
        break
    fi
    sleep 2
done

# 4. Send a standard, an express and a poison order, retried until order-api accepts them.
run_id="solve-$(date +%s)"
send() {
    for _ in $(seq 1 30); do
        curl -s -m 10 -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
            -d "{\"orderId\":\"$run_id-$1\",\"item\":\"$2\",\"quantity\":1,\"priority\":\"$3\"}" | grep -q "$run_id-$1" && return 0
        sleep 2
    done
}
send 1 coffee-beans standard
send 2 coffee-beans express
send 3 poison standard

# 5. Wait until shipping has logged the routing and the dead-lettering of this run's orders.
for _ in $(seq 1 60); do
    log=$(latest_app_log 5 shipping)
    if [ -n "$log" ] && grep -q "shipping standard order $run_id-1" "$log" \
        && grep -q "shipping express order $run_id-2" "$log" \
        && grep -q "shipping dead-lettered order $run_id-3" "$log"; then
        echo "Started demo 5 in .NET and sent three orders ($run_id-1 to $run_id-3): shipping routed them and dead-lettered the poison order (whichever language you used before)."
        exit 0
    fi
    sleep 2
done
echo "The orders did not reach shipping within 2 minutes. See /tmp/dapr-pubsub-demo5.log" >&2
exit 1
