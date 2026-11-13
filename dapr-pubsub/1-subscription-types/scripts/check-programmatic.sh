#!/usr/bin/env bash
set -u
# shellcheck disable=SC1091  # lib-checks.sh is resolved from the script folder at run time
. "$(dirname "$0")/../../scripts/lib-checks.sh"

type=$(metadata_sub_type 3512 orders)
# Gate: when invoicing's sidecar does not answer, check-apps-running.sh reports it. Pass here so
# the learner sees only that hint, not a second, misleading one.
[ -n "$type" ] || exit 0
if [ "$type" != "PROGRAMMATIC" ]; then
    echo "Invoicing's subscription to the orders topic is '$type', not PROGRAMMATIC."
    exit 1
fi
echo "Invoicing's subscription to orders is PROGRAMMATIC."
