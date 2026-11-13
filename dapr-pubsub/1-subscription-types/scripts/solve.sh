#!/usr/bin/env bash
set -e
export PATH="${HOME:-/root}/.local/bin:$PATH:/usr/local/bin"
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-${HOME:-/root}/ai-agent-tracks-instruqt}"
PUBSUB="$TRACKS_SRC_DIR/pubsub"
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

# 1. Stop whatever the learner has running (any demo, any language) so the ports are free again.
for dir in "$PUBSUB"/dotnet/Demo*-* "$PUBSUB"/python/demo*-* "$PUBSUB"/java/demo*-*; do
    [ -f "$dir/dapr.yaml" ] && { (cd "$dir" && dapr stop -f . >/dev/null 2>&1) || true; }
done
for _ in $(seq 1 30); do
    curl -s -o /dev/null -m 2 http://localhost:5101/ || break
    sleep 1
done

# 2. Start demo 1 in .NET in the background. The check only needs the apps to answer and log, so it
# does not matter which language the learner used.
cd "$PUBSUB/dotnet/Demo1-Subscriptions"
if command -v setsid >/dev/null 2>&1; then
    setsid nohup dapr run -f . </dev/null >/tmp/dapr-pubsub-demo1.log 2>&1 &
else
    nohup dapr run -f . </dev/null >/tmp/dapr-pubsub-demo1.log 2>&1 &
fi

# 3. Wait until all three apps answer, then send one order to the topic both subscribe to.
for _ in $(seq 1 120); do
    if port_answers 5101 && port_answers 5102 && port_answers 5103 \
        && [ "$(metadata_sub_type 3511 orders)" = "DECLARATIVE" ] \
        && [ "$(metadata_sub_type 3512 orders)" = "PROGRAMMATIC" ]; then
        break
    fi
    sleep 2
done
order="solve-$(date +%s)"
for _ in $(seq 1 30); do
    curl -s -m 10 -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
        -d "{\"orderId\":\"$order\",\"item\":\"coffee-beans\",\"quantity\":2,\"priority\":\"standard\"}" \
        | grep -q "$order" && break
    sleep 2
done

# 4. Wait until both subscribers have logged it.
for _ in $(seq 1 60); do
    ship=$(latest_app_log 1 shipping)
    inv=$(latest_app_log 1 invoicing)
    if [ -n "$ship" ] && [ -n "$inv" ] \
        && grep -q "shipping received order $order" "$ship" \
        && grep -q "invoicing received order $order" "$inv"; then
        echo "Started demo 1 in .NET and sent order $order: shipping and invoicing both received it (whichever language you used before)."
        exit 0
    fi
    sleep 2
done
echo "The order did not reach both subscribers within 2 minutes. See /tmp/dapr-pubsub-demo1.log" >&2
exit 1
