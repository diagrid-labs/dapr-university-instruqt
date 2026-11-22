# shellcheck shell=bash
# Lab-specific setup for dapr-bindings. The dapr-sandbox module builds the VM startup script as
# `( export <inputs>; source /usr/local/lib/dapr-sandbox/sandbox-setup.sh; <this lab script> )`
# under `set -euo pipefail`, and writes the ready marker itself once the subshell succeeds. So the
# module's shared setup has already run when this file starts: Docker is up, DNS and outbound HTTPS
# work, the demo repo is cloned at the pinned ref, the Editor and Dev Dashboard run, and
# `dapr init` is done. Available here: the functions `log`, `die`, `bounded`, `wait_for_docker`
# and the variables HOME, TRACKS_SRC_DIR, LAB_SETUP_LOG. -e/-u/pipefail are inherited, `exit` only
# leaves the subshell, and nothing here may touch the marker.
#
# The lab script is start-postgres.sh (defines start_postgres) followed by this file. The
# lab-specific work: pre-build the demo apps in the background, then start PostgreSQL (the image
# is already in the sandbox image) and wait for its tables, because pages 2 to 4 use it and a
# learner can skip pages. Safe to re-run.
: "${TRACKS_SRC_DIR:?TRACKS_SRC_DIR must be set (set by the module sandbox-setup.sh)}"

if [ ! -d "$TRACKS_SRC_DIR/bindings" ]; then
    die "$TRACKS_SRC_DIR/bindings not found. Is $TRACKS_SRC_DIR a current clone of diagrid-labs/university-labs?"
fi

# Pre-build the apps of demos 1 to 4 in a fully detached background job (own stdin, stdout and
# stderr), so the sandbox reports ready without waiting for the builds: demo 1 first (page 1),
# then demos 2 to 4 in page order. Folder names follow each language: PascalCase for .NET,
# kebab-case for Python and Java. A learner who runs `dapr run -f .` before a build has finished
# only waits for that build. A failed build is logged and never fails the lab.
# Progress: `tail -f /var/log/lab-prebuild.log`.
BINDINGS_BASE="$TRACKS_SRC_DIR/bindings"
PREBUILD_LOG="${LAB_PREBUILD_LOG:-/var/log/lab-prebuild.log}"
touch "$PREBUILD_LOG" 2>/dev/null || PREBUILD_LOG=/dev/null
nohup bash -s -- "$BINDINGS_BASE" >>"$PREBUILD_LOG" 2>&1 <<'PREBUILD' &
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
    "Demo1-CronTrigger:demo1-cron-trigger:Engineering:engineering" \
    "Demo2-PostgresOutput:demo2-postgres-output:Engineering:engineering" \
    "Demo3-StateVsBinding:demo3-state-vs-binding:Engineering:engineering" \
    "Demo4-SubspaceBeacon:demo4-subspace-beacon:Engineering SubspaceBeacon:engineering subspace-beacon"; do
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

start_postgres "$BINDINGS_BASE/sql" || die "Postgres for the bindings demos did not start"
log "Postgres (bindings-postgres) is up with the bindings tables"
log "done after ${SECONDS}s"
