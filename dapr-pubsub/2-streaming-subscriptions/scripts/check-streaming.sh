#!/usr/bin/env bash
set -u
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

type=$(metadata_sub_type 3511 orders)
# Gate: when warehouse's sidecar does not answer, check-apps-running.sh reports it. Pass here so
# the learner sees only that hint, not a second, misleading one.
[ -n "$type" ] || exit 0
if [ "$type" != "STREAMING" ]; then
    echo "The subscription of the warehouse to the orders topic is '$type', not STREAMING. The stream opens a moment after the app starts: wait for the Dapr CLI window to settle and run the check again."
    exit 1
fi
echo "The subscription of the warehouse to orders is STREAMING."
