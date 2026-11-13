#!/usr/bin/env bash
set -u
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

# Gate: only when order-api's sidecar answers. Otherwise check-apps-running.sh reports it.
[ "$(metadata_app_id 3510)" = "order-api" ] || exit 0

type=$(metadata_component_type 3510 pubsub)
# A pubsub.redis component is the previous page's demo still running: check-apps-running.sh says so.
[ "$type" = "pubsub.redis" ] && exit 0
if [ "$type" != "pubsub.rabbitmq" ]; then
    echo "The sidecar of order-api (port 3510) reports the component 'pubsub' as '$type', not pubsub.rabbitmq. Check that you started 'dapr run -f .' in the Demo6-SwapProvider (or demo6-swap-provider) folder."
    exit 1
fi
echo "The component 'pubsub' is of type pubsub.rabbitmq."
