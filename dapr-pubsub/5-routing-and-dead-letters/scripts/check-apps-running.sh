#!/usr/bin/env bash
set -u
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

# The first condition of the page. When it fails, the others are gated, so this message is the only
# hint the learner gets. Demos 1, 3, 4 and 5 all run `shipping` on 3511 with an orders subscription.
# Demo 5 is the one whose orders subscription starts with the express rule, so its first route is
# /orders/express. Demo 6 runs the same apps and files, so page 6 can use the same test.
shipping_id=$(metadata_app_id 3511)
if [ -n "$shipping_id" ]; then
    route=$(metadata_sub_route 3511 orders)
    if [ "$shipping_id" = "shipping" ] && { [ -z "$route" ] || [ "$route" = "NONE" ]; }; then
        echo "The sidecar of shipping on port 3511 answers but cannot report its subscriptions yet. The app is still starting. Wait a few seconds and run the check again."
        exit 1
    fi
    if [ "$shipping_id" != "shipping" ] || [ "$route" != "/orders/express" ]; then
        echo "The sidecar on port 3511 belongs to '$shipping_id' and does not route express orders to /orders/express, so it is not this page's demo. Another page's demo is still running. Press Ctrl+C in the Dapr CLI window to stop it, then start this page's demo (Demo5-RoutingDeadLetter or demo5-routing-dead-letter)."
        exit 1
    fi
fi
missing=""
port_answers 5101 || missing="$missing 5101 (order-api)"
port_answers 5102 || missing="$missing 5102 (shipping)"
[ -n "$shipping_id" ] || missing="$missing 3511 (the sidecar of shipping)"
if [ -n "$missing" ]; then
    echo "Nothing answers on port(s)$missing. Is 'dapr run -f .' running in this page's demo folder (Demo5-RoutingDeadLetter or demo5-routing-dead-letter)? If another page's demo is still running, press Ctrl+C in the Dapr CLI window first."
    exit 1
fi
echo "order-api and shipping answer on ports 5101 and 5102."
