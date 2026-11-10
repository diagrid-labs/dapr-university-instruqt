# shellcheck shell=bash
# Lab setup for dapr-secrets. The dapr-sandbox module inlines this file in the VM startup script
# as `( : <script> )` under `set -euo pipefail`, appended after seed-vault.sh, and writes the
# ready marker itself once this succeeds. So: -e/-u/pipefail are inherited, `exit` only leaves
# the subshell, and nothing here may touch the marker.
#
# Needs DAPR_RUNTIME_VERSION and TRACKS_SRC_REF in the environment. Safe to re-run: the demo clone
# and the Dapr containers are left alone when they already exist, Vault is re-seeded.
set -euo pipefail

# The startup script runs as root at boot, where HOME may be unset or point elsewhere. The lab's
# tabs and tasks hardcode /root, so root always uses /root.
if [ "$(id -u)" -eq 0 ]; then
    HOME=/root
else
    HOME="${HOME:-/root}"
fi
export HOME
: "${DAPR_RUNTIME_VERSION:?DAPR_RUNTIME_VERSION must be set}"
: "${TRACKS_SRC_REF:?TRACKS_SRC_REF must be set}"
export PATH="$PATH:/usr/local/bin:$HOME/.local/bin"

# Instruqt only shows the startup script's output in the lab Logs once the script has ended. Keep
# a timestamped copy of every step on the VM as well, so a slow or stuck start can be followed
# live: `tail -f /var/log/lab-setup.log` in a lab terminal. When the file cannot be written (a
# local run as a normal user) the copy goes to /dev/null rather than failing the setup.
LAB_SETUP_LOG="${LAB_SETUP_LOG:-/var/log/lab-setup.log}"
touch "$LAB_SETUP_LOG" 2>/dev/null || LAB_SETUP_LOG=/dev/null
log() { # log <message>: timestamped line to stdout and the log file
    printf '%s lab-setup: %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$LAB_SETUP_LOG"
}
die() { # die <message>: log an error to stderr and the log file, then stop
    log "ERROR: $*" >&2
    exit 1
}
log "start (pinned ref $TRACKS_SRC_REF, Dapr runtime $DAPR_RUNTIME_VERSION)"

# Docker may still be starting when the startup script runs at boot. Wait for the daemon before
# the first docker use, and fail clearly if it never comes up.
docker_ready=0
for _ in $(seq 1 60); do
    if docker info >/dev/null 2>&1; then
        docker_ready=1
        break
    fi
    sleep 1
done
if [ "$docker_ready" -ne 1 ]; then
    die "Docker daemon not ready after 60 seconds."
fi
log "Docker ready"

# DNS may not be up yet either: a first sandbox start failed with "Could not resolve host:
# github.com" on the clone below. Wait until public names resolve before anything that needs the
# internet (the clone, and `dapr init` if an image is missing), and fail clearly if they never do.
dns_ready=0
for attempt in $(seq 1 120); do
    if getent hosts github.com >/dev/null 2>&1; then
        dns_ready=1
        log "DNS ready after ${attempt}s"
        break
    fi
    [ $((attempt % 10)) -eq 0 ] && log "waiting for DNS (${attempt}s)"
    sleep 1
done
if [ "$dns_ready" -ne 1 ]; then
    die "github.com does not resolve after 120 seconds; the VM has no working DNS."
fi

# The demo repo holds the three-language apps and the scoping/Vault resources. It lives at a
# fixed path because the track-tester suites and the assignments both refer to it.
TRACKS_SRC_DIR="$HOME/ai-agent-tracks-instruqt"
TRACKS_SRC_URL="https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git"
# The startup script runs early in boot and as root: allow git to use the clone regardless of
# which user owns it, so a later git call cannot fail with "dubious ownership" (exit 128).
git config --global --add safe.directory "$TRACKS_SRC_DIR"
# -e, not -d: in a git worktree the .git entry is a file.
if [ ! -e "$TRACKS_SRC_DIR/.git" ]; then
    # The network (DNS) may not be up yet at boot, and a failed clone leaves a partial directory
    # that makes the next `git clone` fail. Retry with a clean target and log each attempt, so the
    # lab's Logs show why setup stopped instead of a bare "exited with code 128".
    cloned=0
    for attempt in $(seq 1 12); do
        rm -rf "$TRACKS_SRC_DIR"
        log "cloning $TRACKS_SRC_URL (attempt $attempt)"
        if git clone --quiet "$TRACKS_SRC_URL" "$TRACKS_SRC_DIR"; then
            cloned=1
            break
        fi
        sleep 5
    done
    if [ "$cloned" -ne 1 ]; then
        die "could not clone $TRACKS_SRC_URL after 12 attempts (is the network up?)."
    fi
    log "checking out $TRACKS_SRC_REF"
    git -C "$TRACKS_SRC_DIR" checkout --quiet "$TRACKS_SRC_REF"
fi
# Warn (never fail) when the checkout is not at the pinned ref: a pre-existing directory may hold
# a learner's edits.
if [ "$(git -C "$TRACKS_SRC_DIR" rev-parse HEAD)" != "$TRACKS_SRC_REF" ]; then
    echo "WARNING: $TRACKS_SRC_DIR is not at the pinned ref $TRACKS_SRC_REF." >&2
fi

# `dapr init` is skipped when the containers are already running, so a re-run does not tear down
# and re-create them.
dapr_containers_running() {
    [ -n "$(docker ps -f "name=dapr_placement" -f "status=running" -q)" ] &&
        [ -n "$(docker ps -f "name=dapr_scheduler" -f "status=running" -q)" ] &&
        [ -n "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]
}
if dapr_containers_running; then
    log "Dapr containers already running"
else
    log "dapr init --runtime-version $DAPR_RUNTIME_VERSION"
    dapr init --runtime-version "$DAPR_RUNTIME_VERSION"
    log "dapr init done"
fi

# secrets.json is generated by copying the committed template, the single owner of the secret
# values (also used to seed Vault). The copy truncates, so a re-run leaves identical bytes.
if [ ! -f "$TRACKS_SRC_DIR/secrets/secrets.example.json" ]; then
    die "$TRACKS_SRC_DIR/secrets/secrets.example.json not found. Is $TRACKS_SRC_DIR a current clone of diagrid-labs/ai-agent-tracks-instruqt?"
fi
cp "$TRACKS_SRC_DIR/secrets/secrets.example.json" "$TRACKS_SRC_DIR/secrets/secrets.json"

# seed_vault comes from seed-vault.sh. On the VM it is concatenated in front of this script; in a
# standalone run (local, tests) it is sourced from next to this file.
if ! declare -F seed_vault >/dev/null; then
    # shellcheck source=/dev/null
    source "$(dirname "${BASH_SOURCE[0]}")/seed-vault.sh"
fi
log "starting and seeding Vault"
seed_vault "$TRACKS_SRC_DIR/secrets/secrets.json"
log "Vault seeded"

# Pre-build all demo apps in a fully detached background job (own stdin, stdout and stderr), so
# the sandbox reports ready without waiting for the builds: Demo1-ReadSecret first (challenges 1,
# 2 and 4), then Demo2-Scoping (challenge 3). A learner who runs `dapr run -f .` before a build has
# finished only waits for that build. A failed build is logged and never fails the lab. Progress:
# `tail -f /var/log/lab-prebuild.log`.
SECRETS_BASE="$TRACKS_SRC_DIR/secrets"
PREBUILD_LOG="${LAB_PREBUILD_LOG:-/var/log/lab-prebuild.log}"
touch "$PREBUILD_LOG" 2>/dev/null || PREBUILD_LOG=/dev/null
nohup bash -s -- "$SECRETS_BASE" >>"$PREBUILD_LOG" 2>&1 <<'PREBUILD' &
base="$1"
build() { # build <dir> <command...>
    local dir="$1"; shift
    if [ -d "$dir" ]; then
        echo "$(date -u +%H:%M:%S) == $dir: $*"
        (cd "$dir" && "$@" </dev/null) || echo "WARN: build failed in $dir"
    fi
}
for demo in Demo1-ReadSecret Demo2-Scoping/AppA Demo2-Scoping/AppB; do
    build "$base/dotnet/$demo" dotnet build
    build "$base/python/$demo" uv sync
    build "$base/java/$demo" mvn -q -DskipTests package
done
echo "$(date -u +%H:%M:%S) == prebuild done"
PREBUILD
log "demo pre-build started in the background (/var/log/lab-prebuild.log)"
log "done after ${SECONDS}s"
