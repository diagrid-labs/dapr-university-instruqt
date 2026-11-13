#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

# Demo 6 runs the demo 5 apps and subscriptions, so shipping on 3511 looks exactly like page 5's
# (the first route of its orders subscription is /orders/express). What tells the demos apart is the
# type of the `pubsub` component: pubsub.rabbitmq here, pubsub.redis on page 5.
shipping_id=$(metadata_app_id 3511)
if [ -n "$shipping_id" ]; then
    route=$(metadata_sub_route 3511 orders)
    if [ "$shipping_id" = "shipping" ] && { [ -z "$route" ] || [ "$route" = "NONE" ]; }; then
        echo "The sidecar of shipping on port 3511 answers but cannot report its subscriptions yet. The app is still starting. Wait a few seconds and run the check again."
        exit 1
    fi
    if [ "$shipping_id" != "shipping" ] || [ "$route" != "/orders/express" ]; then
        echo "The sidecar on port 3511 belongs to '$shipping_id' and does not route express orders to /orders/express, so it is not this page's demo. Another page's demo is still running. Press Ctrl+C in the Dapr CLI window to stop it (if Skip or Solve started it, run the stop command under 'Before you start' instead), then start this page's demo (Demo6-SwapProvider or demo6-swap-provider)."
        exit 1
    fi
    type=$(metadata_component_type 3511 pubsub)
    if [ -z "$type" ] || [ "$type" = "NONE" ]; then
        echo "The sidecar of shipping on port 3511 does not report a component named 'pubsub' yet. If the apps are still starting, wait a few seconds and run the check again. Otherwise press Ctrl+C in the Dapr CLI window and start this page's demo (Demo6-SwapProvider or demo6-swap-provider)."
        exit 1
    fi
    if [ "$type" != "pubsub.rabbitmq" ]; then
        echo "The component 'pubsub' of shipping is of type '$type', not pubsub.rabbitmq. The demo of the previous page is still running on Redis. Press Ctrl+C in the Dapr CLI window to stop it (if Skip or Solve started it, run the stop command under 'Before you start' instead), then start this page's demo (Demo6-SwapProvider or demo6-swap-provider)."
        exit 1
    fi
fi
missing=""
port_answers 5101 || missing="$missing 5101 (order-api)"
port_answers 5102 || missing="$missing 5102 (shipping)"
[ -n "$shipping_id" ] || missing="$missing 3511 (the sidecar of shipping)"
if [ -n "$missing" ]; then
    echo "Nothing answers on port(s)$missing. Is 'dapr run -f .' running in this page's demo folder (Demo6-SwapProvider or demo6-swap-provider)? If another page's demo is still running, press Ctrl+C in the Dapr CLI window first."
    exit 1
fi
echo "order-api and shipping answer on ports 5101 and 5102, on RabbitMQ."
