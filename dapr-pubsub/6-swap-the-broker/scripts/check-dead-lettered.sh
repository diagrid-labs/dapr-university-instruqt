#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

# Gate: only when demo 6's shipping answers on RabbitMQ. Otherwise check-apps-running.sh reports it.
[ "$(metadata_app_id 3511)" = "shipping" ] || exit 0
[ "$(metadata_sub_route 3511 orders)" = "/orders/express" ] || exit 0
[ "$(metadata_component_type 3511 pubsub)" = "pubsub.rabbitmq" ] || exit 0

# Dapr created a queue per subscription, named <app-id>-<topic>, when the apps started.
queues=$(curl -s -m 5 -u guest:guest http://localhost:15672/api/queues 2>/dev/null | python3 -c '
import json, sys
try:
    print("\n".join(q.get("name", "") for q in json.load(sys.stdin)))
except (ValueError, AttributeError):
    pass' 2>/dev/null)
if [ -z "$queues" ]; then
    echo "The RabbitMQ management API on port 15672 does not answer. Start RabbitMQ with the Run block in step 1 first."
    exit 1
fi
if ! echo "$queues" | grep -qx "shipping-orders-dead"; then
    echo "RabbitMQ has no queue 'shipping-orders-dead' yet. Send the three orders with the command in step 4, wait a few seconds for the retries, then run the check again."
    exit 1
fi

# Demo 6 logs land in the demo 5 app folders (same apps). Only the poison order is dead-lettered.
log=$(latest_app_log 6 shipping)
if [ -z "$log" ] || ! grep -q "shipping dead-lettered order" "$log"; then
    echo "No 'shipping dead-lettered order' line yet in the log of shipping. Send the three orders with the command in step 4, wait a few seconds for the retries, then run the check again."
    exit 1
fi
echo "RabbitMQ has the queue shipping-orders-dead and shipping received a dead-lettered order."
