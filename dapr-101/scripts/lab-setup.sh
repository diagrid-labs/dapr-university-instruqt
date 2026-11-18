# shellcheck shell=bash
# Lab-specific setup for dapr-101. The dapr-sandbox module builds the VM startup script as
# `( export <inputs>; source /usr/local/lib/dapr-sandbox/sandbox-setup.sh; <this lab script> )`
# under `set -euo pipefail`, and writes the ready marker itself once the subshell succeeds. So the
# module's shared setup has already run when this file starts: Docker is up, DNS and outbound HTTPS
# work, the demo repo is cloned at the pinned ref, the Editor and Dev Dashboard run, and
# `dapr init` is done. Available here: the functions `log`, `die`, `bounded`, `wait_for_docker`
# and the variables HOME, TRACKS_SRC_DIR, LAB_SETUP_LOG. -e/-u/pipefail are inherited, `exit` only
# leaves the subshell, and nothing here may touch the marker.
#
# The lab-specific work: pre-build the demo apps in the background. Safe to re-run.
: "${TRACKS_SRC_DIR:?TRACKS_SRC_DIR must be set (set by the module sandbox-setup.sh)}"

if [ ! -d "$TRACKS_SRC_DIR/dapr-101" ]; then
    die "$TRACKS_SRC_DIR/dapr-101 not found. Is $TRACKS_SRC_DIR a current clone of diagrid-labs/ai-agent-tracks-instruqt?"
fi

# Pre-build the apps of the page 4 (service invocation) and page 5 (pub/sub) demos in a fully
# detached background job (own stdin, stdout and stderr), so the sandbox reports ready without
# waiting for the builds: page 4 first, then page 5. Folder names follow each language: PascalCase
# for .NET, kebab-case for the others. A learner who runs `dapr run -f .` before a build has
# finished only waits for that build. A failed build is logged and never fails the lab.
# Progress: `tail -f /var/log/lab-prebuild.log`.
DAPR101_BASE="$TRACKS_SRC_DIR/dapr-101"
PREBUILD_LOG="${LAB_PREBUILD_LOG:-/var/log/lab-prebuild.log}"
touch "$PREBUILD_LOG" 2>/dev/null || PREBUILD_LOG=/dev/null
nohup bash -s -- "$DAPR101_BASE" >>"$PREBUILD_LOG" 2>&1 <<'PREBUILD' &
base="$1"
build() { # build <dir> <command...>
    local dir="$1"; shift
    if [ -d "$dir" ]; then
        echo "$(date -u +%H:%M:%S) == $dir: $*"
        (cd "$dir" && "$@" </dev/null) || echo "WARN: build failed in $dir"
    fi
}
# <demo dotnet>:<demo python/java/javascript>
for spec in "ServiceInvocation:service-invocation" "PubSub:pub-sub"; do
    IFS=: read -r dn dp <<<"$spec"
    for app in checkout order-processor; do
        build "$base/dotnet/$dn/$app" dotnet build
    done
    # Python demos are a uv workspace: sync once at the demo root.
    build "$base/python/$dp" uv sync --all-packages
    for app in checkout order-processor; do
        build "$base/java/$dp/$app" mvn -q -DskipTests install
        build "$base/javascript/$dp/$app" npm install
    done
done
echo "$(date -u +%H:%M:%S) == prebuild done"
PREBUILD
log "demo pre-build started in the background (/var/log/lab-prebuild.log)"
log "done after ${SECONDS}s"
