# shellcheck shell=bash
# Lab-specific setup for dapr-pubsub. The dapr-sandbox module builds the VM startup script as
# `( export <inputs>; source /usr/local/lib/dapr-sandbox/sandbox-setup.sh; <this lab script> )`
# under `set -euo pipefail`, and writes the ready marker itself once the subshell succeeds. So the
# module's shared setup has already run when this file starts: Docker is up, DNS and outbound HTTPS
# work, the demo repo is cloned at the pinned ref, the Editor and Dev Dashboard run, and
# `dapr init` is done. Available here: the functions `log`, `die`, `bounded`, `wait_for_docker`
# and the variables HOME, TRACKS_SRC_DIR, LAB_SETUP_LOG. -e/-u/pipefail are inherited, `exit` only
# leaves the subshell, and nothing here may touch the marker.
#
# versions.hcl puts scripts/lib-checks.sh in front of this file, so its helpers are defined here.
# The lab-specific work: install those helpers for the check and solve scripts, and pre-build the
# demo apps in the background. The RabbitMQ image is already in the sandbox image; page 6 starts the
# broker. Safe to re-run.
: "${TRACKS_SRC_DIR:?TRACKS_SRC_DIR must be set (set by the module sandbox-setup.sh)}"

# The check and solve scripts run on the VM, where the lab's files are not, so they source the
# helpers from this fixed path (and fall back to the repo copy in CI and pytest). Every function of
# lib-checks.sh must be listed: `declare -f` fails, and so does the lab, when one is not defined.
LAB_CHECKS_LIB_DIR="${LAB_CHECKS_LIB_DIR:-/usr/local/lib/dapr-pubsub}"
mkdir -p "$LAB_CHECKS_LIB_DIR"
{
    echo "# shellcheck shell=bash"
    echo "# Written by dapr-pubsub/scripts/lab-setup.sh from scripts/lib-checks.sh. Do not edit."
    declare -f latest_app_log port_answers metadata_app_id metadata_sub_type metadata_sub_route \
        metadata_component_type stop_all_demos start_demo_detached
} >"$LAB_CHECKS_LIB_DIR/lib-checks.sh"
log "check helpers installed in $LAB_CHECKS_LIB_DIR/lib-checks.sh"

if [ ! -d "$TRACKS_SRC_DIR/pubsub" ]; then
    die "$TRACKS_SRC_DIR/pubsub not found. Is $TRACKS_SRC_DIR a current clone of diagrid-labs/ai-agent-tracks-instruqt?"
fi

# Pre-build the apps of demos 1 to 5 in a fully detached background job (own stdin, stdout and
# stderr), so the sandbox reports ready without waiting for the builds: demo 1 first (page 1),
# then demos 2 to 5 in page order. Demo 6 reuses the demo 5 apps. Folder names follow each
# language: PascalCase for .NET, kebab-case for Python and Java. A learner who runs
# `dapr run -f .` before a build has finished only waits for that build. A failed build is logged
# and never fails the lab. Progress: `tail -f /var/log/lab-prebuild.log`.
PUBSUB_BASE="$TRACKS_SRC_DIR/pubsub"
PREBUILD_LOG="${LAB_PREBUILD_LOG:-/var/log/lab-prebuild.log}"
touch "$PREBUILD_LOG" 2>/dev/null || PREBUILD_LOG=/dev/null
nohup bash -s -- "$PUBSUB_BASE" >>"$PREBUILD_LOG" 2>&1 <<'PREBUILD' &
base="$1"
build() { # build <dir> <command...>
    local dir="$1"; shift
    if [ -d "$dir" ]; then
        echo "$(date -u +%H:%M:%S) == $dir: $*"
        (cd "$dir" && "$@" </dev/null) || echo "WARN: build failed in $dir"
    fi
}
# <demo dotnet>:<demo python/java>:<apps dotnet>:<apps python/java>
for spec in \
    "Demo1-Subscriptions:demo1-subscriptions:OrderApi Shipping Invoicing:order-api shipping invoicing" \
    "Demo2-Streaming:demo2-streaming:OrderApi Warehouse:order-api warehouse" \
    "Demo3-CloudEvents:demo3-cloud-events:OrderApi Shipping:order-api shipping" \
    "Demo4-Bulk:demo4-bulk:OrderApi Shipping:order-api shipping" \
    "Demo5-RoutingDeadLetter:demo5-routing-dead-letter:OrderApi Shipping:order-api shipping"; do
    IFS=: read -r dn dp adn adp <<<"$spec"
    for app in $adn; do
        build "$base/dotnet/$dn/$app" dotnet build
    done
    for app in $adp; do
        build "$base/python/$dp/$app" uv sync
        build "$base/java/$dp/$app" mvn -q -DskipTests package
    done
done
echo "$(date -u +%H:%M:%S) == prebuild done"
PREBUILD
log "demo pre-build started in the background (/var/log/lab-prebuild.log)"
log "done after ${SECONDS}s"
