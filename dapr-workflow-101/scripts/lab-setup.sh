# shellcheck shell=bash
# Lab-specific setup for dapr-workflow-101. The dapr-sandbox module builds the VM startup script as
# `( export <inputs>; source /usr/local/lib/dapr-sandbox/sandbox-setup.sh; <this lab script> )`
# under `set -euo pipefail`, and writes the ready marker itself once the subshell succeeds. So the
# module's shared setup has already run when this file starts: Docker is up, DNS and outbound HTTPS
# work, the demo repo is cloned at the pinned ref, the Editor and Dev Dashboard run, and
# `dapr init` is done. Available here: the functions `log`, `die`, `bounded`, `wait_for_docker`
# and the variables HOME, TRACKS_SRC_DIR, LAB_SETUP_LOG. -e/-u/pipefail are inherited, `exit` only
# leaves the subshell, and nothing here may touch the marker.
#
# The only lab-specific work is pre-building the demo apps in the background. The demos need no
# service of their own: workflow state lives in the Redis container that `dapr init` starts.
# Safe to re-run.
: "${TRACKS_SRC_DIR:?TRACKS_SRC_DIR must be set (set by the module sandbox-setup.sh)}"

if [ ! -d "$TRACKS_SRC_DIR/workflow" ]; then
    die "$TRACKS_SRC_DIR/workflow not found. Is $TRACKS_SRC_DIR a current clone of diagrid-labs/university-labs?"
fi

# Pre-build the engineering app of demos 1 to 6 in a fully detached background job (own stdin,
# stdout and stderr), so the sandbox reports ready without waiting for the builds: demo 1 first
# (page 1), then demos 2 to 6 in page order. Folder names follow each language: PascalCase for
# .NET, kebab-case for Python, Java and TypeScript. A learner who runs `dapr run -f .` before a
# build has finished only waits for that build, except in TypeScript: `npm ci` deletes
# node_modules before it installs, so `npm start` fails because `tsx` is not found until it is
# done (page 1 says to run the app again). The image's npm cache keeps that window short, and
# `npm ci` is skipped where node_modules already exists, so a re-run never deletes it. A failed
# build is logged and never fails the lab.
# Progress: `tail -f /var/log/lab-prebuild.log`.
WF101_BASE="$TRACKS_SRC_DIR/workflow"
PREBUILD_LOG="${LAB_PREBUILD_LOG:-/var/log/lab-prebuild.log}"
touch "$PREBUILD_LOG" 2>/dev/null || PREBUILD_LOG=/dev/null
nohup bash -s -- "$WF101_BASE" >>"$PREBUILD_LOG" 2>&1 <<'PREBUILD' &
base="$1"
build() { # build <dir> <command...>
    local dir="$1"; shift
    if [ -d "$dir" ]; then
        echo "$(date -u +%H:%M:%S) == $dir: $*"
        (cd "$dir" && "$@" </dev/null) || echo "WARN: build failed in $dir"
    fi
}
# <demo dotnet>:<demo python/java/typescript>
for spec in \
    "Demo1-DurableExecution:demo1-durable-execution" \
    "Demo2-TaskChaining:demo2-task-chaining" \
    "Demo3-FanOutFanIn:demo3-fan-out-fan-in" \
    "Demo4-Monitor:demo4-monitor" \
    "Demo5-HumanInTheLoop:demo5-human-in-the-loop" \
    "Demo6-Management:demo6-management"; do
    IFS=: read -r dn dk <<<"$spec"
    build "$base/dotnet/$dn/Engineering" dotnet build
    build "$base/python/$dk/engineering" uv sync
    build "$base/java/$dk/engineering" mvn -q -DskipTests package
    if [ ! -d "$base/typescript/$dk/engineering/node_modules" ]; then
        build "$base/typescript/$dk/engineering" npm ci
    fi
done
echo "$(date -u +%H:%M:%S) == prebuild done"
PREBUILD
log "demo pre-build started in the background (/var/log/lab-prebuild.log)"
log "done after ${SECONDS}s"
