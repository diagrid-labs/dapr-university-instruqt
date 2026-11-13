#!/usr/bin/env bash
set -u
# The lab's files are not on the VM: lab-setup.sh installs the helpers at this fixed path. The repo
# copy next to the lab is the fallback for CI and pytest.
LIB_CHECKS=/usr/local/lib/dapr-pubsub/lib-checks.sh
[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"
# shellcheck disable=SC1090,SC1091  # resolved at run time
. "$LIB_CHECKS"

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
