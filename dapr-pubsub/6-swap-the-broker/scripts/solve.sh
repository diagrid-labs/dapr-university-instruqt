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
for _ in $(seq 1 15); do
    curl -s -o /dev/null -m 2 http://localhost:5101/ || break
    sleep 1
done

# 2. Start RabbitMQ the way step 1 does. Safe to run again: any existing container goes first.
docker rm -f rabbitmq >/dev/null 2>&1 || true
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:4.4.0-management >/dev/null
for _ in $(seq 1 45); do
    docker exec -u rabbitmq rabbitmq rabbitmq-diagnostics -q ping >/dev/null 2>&1 && break
    sleep 1
done

# 3. Start demo 6 in .NET in the background.
cd "$PUBSUB/dotnet/Demo6-SwapProvider"
if command -v setsid >/dev/null 2>&1; then
    setsid nohup dapr run -f . </dev/null >/tmp/dapr-pubsub-demo6.log 2>&1 &
else
    nohup dapr run -f . </dev/null >/tmp/dapr-pubsub-demo6.log 2>&1 &
fi

# 4. Wait (at most 90 seconds, the apps are pre-built) until both apps answer and the component is
# RabbitMQ. Fail here with the log file named instead of sending orders to apps that are not there.
ready=""
for _ in $(seq 1 45); do
    if port_answers 5101 && port_answers 5102 && [ "$(metadata_component_type 3511 pubsub)" = "pubsub.rabbitmq" ] \
        && [ "$(metadata_sub_route 3511 orders)" = "/orders/express" ]; then
        ready=yes
        break
    fi
    sleep 2
done
if [ -z "$ready" ]; then
    echo "The apps did not come up on RabbitMQ within 90 seconds. See /tmp/dapr-pubsub-demo6.log" >&2
    exit 1
fi

# 5. Send a standard, an express and a poison order, retried until order-api accepts them.
run_id="solve-$(date +%s)"
send() {
    for _ in $(seq 1 3); do
        curl -s -m 5 -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
            -d "{\"orderId\":\"$run_id-$1\",\"item\":\"$2\",\"quantity\":1,\"priority\":\"$3\"}" | grep -q "$run_id-$1" && return 0
        sleep 2
    done
}
send 1 coffee-beans standard
send 2 coffee-beans express
send 3 poison standard

# 6. Wait until shipping has dead-lettered this run's poison order (the logs are in the demo 5 folders).
for _ in $(seq 1 30); do
    log=$(latest_app_log 6 shipping)
    if [ -n "$log" ] && grep -q "shipping dead-lettered order $run_id-3" "$log"; then
        echo "Started RabbitMQ and demo 6 in .NET and sent three orders ($run_id-1 to $run_id-3): shipping dead-lettered the poison order."
        exit 0
    fi
    sleep 2
done
echo "The orders did not reach shipping within 60 seconds. See /tmp/dapr-pubsub-demo6.log" >&2
exit 1
