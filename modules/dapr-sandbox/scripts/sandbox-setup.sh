# shellcheck shell=bash
# Shared sandbox setup for labs on the dapr-sandbox module. The image carries this file at
# /usr/local/lib/dapr-sandbox/sandbox-setup.sh; the module's startup script exports the four
# variables below, sources this file, then runs the lab's own script, all inside one subshell
# under `set -euo pipefail` (inherited, so it is not set here). `die` ends that subshell, which
# fails the startup; nothing here touches the ready marker.
#
# Requires in the environment: DAPR_RUNTIME_VERSION, DEMO_REPO_URL, DEMO_REPO_REF, EDITOR_FOLDER
# (a path relative to the clone). Leaves defined for the lab script: log, die, bounded,
# wait_for_docker, and the exports HOME, TRACKS_SRC_DIR, LAB_SETUP_LOG. Safe to re-run: the demo
# clone and the Dapr containers are left alone when they already exist.

# The startup script runs as root at boot, where HOME may be unset or point elsewhere. The lab's
# tabs and tasks hardcode /root, so root always uses /root.
if [ "$(id -u)" -eq 0 ]; then
    HOME=/root
else
    HOME="${HOME:-/root}"
fi
export HOME
: "${DAPR_RUNTIME_VERSION:?DAPR_RUNTIME_VERSION must be set}"
: "${DEMO_REPO_URL:?DEMO_REPO_URL must be set}"
: "${DEMO_REPO_REF:?DEMO_REPO_REF must be set}"
: "${EDITOR_FOLDER:?EDITOR_FOLDER must be set}"
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
# bounded <seconds> <command...>: run a command that may block (network, Docker) with a hard time
# limit. Without one, a probe that hangs (an unanswered DNS server, a stuck Docker socket) keeps
# the sandbox in "Creating sandbox" with no output at all. `timeout` is coreutils on the VM; a
# local run without it (macOS) runs the command unbounded.
bounded() {
    local secs="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$secs" "$@"
    else
        "$@"
    fi
}
log "start (pinned ref $DEMO_REPO_REF, Dapr runtime $DAPR_RUNTIME_VERSION)"

# Docker may still be starting when the startup script runs at boot. Wait for the daemon before
# the first docker use, and fail clearly if it never comes up.
wait_for_docker() { # wait_for_docker <seconds>
    local deadline=$((SECONDS + $1))
    until bounded 5 docker info >/dev/null 2>&1; do
        [ "$SECONDS" -lt "$deadline" ] || die "Docker daemon not ready after $1 seconds."
        sleep 1
    done
}
wait_for_docker 60
log "Docker ready (${SECONDS}s since start)"

# DNS may not be up yet either: a first sandbox start failed with "Could not resolve host:
# github.com" on the clone below. Wait until public names resolve before anything that needs the
# internet (the clone, and `dapr init` if an image is missing), and fail clearly if they never do.
# Each lookup is capped at 3 seconds and each wait by wall-clock time: a DNS server that never
# answers makes every lookup block, so counting attempts is not enough.
#
# On Instruqt 2.0 the VM's resolver turned out to never answer public names (Instruqt's local DNS
# listener serves sandbox.internal; github.com timed out for 90+ seconds). So: wait briefly for
# the default resolver, then log what the VM has, and if the internet is reachable by IP address,
# put public resolvers in front of the existing ones and wait again.
RESOLV_CONF="${LAB_RESOLV_CONF:-/etc/resolv.conf}"
PUBLIC_DNS="1.1.1.1 8.8.8.8"
wait_for_dns() { # wait_for_dns <seconds>: 0 once github.com resolves, 1 when the time is up
    local deadline=$((SECONDS + $1)) next_note=$((SECONDS + 10))
    until bounded 3 getent hosts github.com >/dev/null 2>&1; do
        [ "$SECONDS" -lt "$deadline" ] || return 1
        if [ "$SECONDS" -ge "$next_note" ]; then
            log "waiting for DNS"
            next_note=$((SECONDS + 10))
        fi
        sleep 1
    done
}
if ! wait_for_dns 20; then
    log "github.com does not resolve with the default resolver"
    log "resolv.conf: $(grep -v '^#' "$RESOLV_CONF" 2>/dev/null | tr '\n' ' ')"
    log "default route: $(ip route show default 2>/dev/null | head -1)"
    if ! curl -sSk -o /dev/null -m 5 https://1.1.1.1 2>/dev/null; then
        die "github.com does not resolve and https://1.1.1.1 is not reachable either; the VM has no outbound internet access (not even by IP address)."
    fi
    log "the internet is reachable by IP address; adding public DNS servers ($PUBLIC_DNS) in front of the existing resolver"
    # Write a plain file (it may be a symlink to a resolver stub) with the public servers first and
    # the existing lines after them, so sandbox-internal names keep resolving where they did.
    existing="$(cat "$RESOLV_CONF" 2>/dev/null || true)"
    rm -f "$RESOLV_CONF"
    {
        echo "# Public resolvers added by sandbox-setup.sh: the default resolver does not answer public names."
        for server in $PUBLIC_DNS; do echo "nameserver $server"; done
        echo "options timeout:2 attempts:2"
        printf '%s\n' "$existing"
    } >"$RESOLV_CONF"
    wait_for_dns 30 ||
        die "github.com still does not resolve after adding public DNS servers ($PUBLIC_DNS); DNS traffic from the VM may be blocked."

    # The Docker daemon does not re-read /etc/resolv.conf: it keeps the resolver it found at its
    # own start (before this script), so image pulls by `dapr init` or the Vault start would still
    # fail to resolve the registry. Give the daemon the same public servers and restart it, as
    # Instruqt's own docker-on-vm guidance does. Existing daemon.json settings are kept.
    DOCKER_DAEMON_JSON="${LAB_DOCKER_DAEMON_JSON:-/etc/docker/daemon.json}"
    mkdir -p "$(dirname "$DOCKER_DAEMON_JSON")"
    # $PUBLIC_DNS is split on purpose: one argument per server.
    # shellcheck disable=SC2086
    python3 - "$DOCKER_DAEMON_JSON" $PUBLIC_DNS <<'PY'
import json, os, sys
path, servers = sys.argv[1], sys.argv[2:]
config = {}
if os.path.exists(path) and os.path.getsize(path) > 0:
    with open(path) as f:
        config = json.load(f)
config["dns"] = servers
with open(path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
PY
    log "set Docker daemon DNS to $PUBLIC_DNS in $DOCKER_DAEMON_JSON; restarting Docker"
    bounded 60 systemctl restart docker || die "restarting Docker after setting its DNS servers failed."
    wait_for_docker 60
    log "Docker ready again with public DNS (${SECONDS}s since start)"
fi
log "DNS ready (${SECONDS}s since start)"

# A name that resolves does not mean the VM can reach the internet. Without outbound access the
# clone below would block on TCP connects for minutes per attempt, and because the lab Logs only
# show this script's output once it ends, the sandbox would sit in "Creating sandbox" with no
# clue. Probe HTTPS with a short timeout first and fail fast with a clear message instead.
deadline=$((SECONDS + 60))
until curl -sS -o /dev/null -m 10 https://github.com 2>/dev/null; do
    [ "$SECONDS" -lt "$deadline" ] || die "github.com resolves but is not reachable over HTTPS after 60 seconds; the VM has no outbound internet access."
    log "github.com not reachable over HTTPS yet"
    sleep 2
done
log "outbound HTTPS to github.com works (${SECONDS}s since start)"

# The demo repo holds the three-language apps and the scoping/Vault resources. It lives at a
# fixed path because the track-tester suites and the assignments both refer to it.
export TRACKS_SRC_DIR="$HOME/ai-agent-tracks-instruqt"
# The startup script runs early in boot and as root: allow git to use the clone regardless of
# which user owns it, so a later git call cannot fail with "dubious ownership" (exit 128).
git config --global --add safe.directory "$TRACKS_SRC_DIR"
# -e, not -d: in a git worktree the .git entry is a file.
if [ ! -e "$TRACKS_SRC_DIR/.git" ]; then
    # The network (DNS) may not be up yet at boot, and a failed clone leaves a partial directory
    # that makes the next `git clone` fail. Retry with a clean target and log each attempt, so the
    # lab's Logs show why setup stopped instead of a bare "exited with code 128".
    # Each attempt is bounded (`bounded 60`, and git aborts a transfer slower than 1 KB/s for 20s),
    # so a stalled network fails the setup within minutes instead of hanging it.
    cloned=0
    for attempt in $(seq 1 3); do
        rm -rf "$TRACKS_SRC_DIR"
        log "cloning $DEMO_REPO_URL (attempt $attempt)"
        if bounded 60 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=20 \
            clone --quiet "$DEMO_REPO_URL" "$TRACKS_SRC_DIR"; then
            cloned=1
            break
        fi
        sleep 5
    done
    if [ "$cloned" -ne 1 ]; then
        die "could not clone $DEMO_REPO_URL after 3 attempts."
    fi
    log "checking out $DEMO_REPO_REF"
    git -C "$TRACKS_SRC_DIR" checkout --quiet "$DEMO_REPO_REF"
fi
# Warn (never fail) when the checkout is not at the pinned ref: a pre-existing directory may hold
# a learner's edits.
if [ "$(git -C "$TRACKS_SRC_DIR" rev-parse HEAD)" != "$DEMO_REPO_REF" ]; then
    echo "WARNING: $TRACKS_SRC_DIR is not at the pinned ref $DEMO_REPO_REF." >&2
fi

# The Editor tab is code-server (VS Code in the browser) on the VM, shown through a `service` tab:
# the built-in `editor` resource showed no files for a VM target. The sandbox image installs it
# (pinned in modules/dapr-sandbox/versions.hcl); run it as a transient systemd service so it
# outlives this startup script and restarts if it stops. It runs as root, like the terminals, on
# the folder they open.
CODE_SERVER_PORT=8888
command -v code-server >/dev/null 2>&1 ||
    die "code-server is not installed; the sandbox image (modules/dapr-sandbox) should provide it."
# VS Code user settings for a distraction-free lab editor:
# - no "A git repository was found in the parent folders" prompt (the editor opens a subfolder
#   of the demo clone),
# - no AI chat/agent panel, and the secondary side bar it opens in stays hidden,
# - no Welcome page, no telemetry.
CODE_SERVER_SETTINGS="$HOME/.local/share/code-server/User/settings.json"
mkdir -p "$(dirname "$CODE_SERVER_SETTINGS")"
cat >"$CODE_SERVER_SETTINGS" <<'JSON'
{
  "git.openRepositoryInParentFolders": "never",
  "chat.disableAIFeatures": true,
  "workbench.secondarySideBar.defaultVisibility": "hidden",
  "workbench.startupEditor": "none",
  "telemetry.telemetryLevel": "off"
}
JSON
code_server_args=(
    --bind-addr "0.0.0.0:${CODE_SERVER_PORT}" --auth none
    --disable-telemetry --disable-update-check --disable-workspace-trust
    "$TRACKS_SRC_DIR/$EDITOR_FOLDER"
)
if command -v systemd-run >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
    systemctl stop code-server-lab >/dev/null 2>&1 || true
    systemd-run --unit=code-server-lab --property=Restart=always \
        --setenv=HOME="$HOME" "$(command -v code-server)" "${code_server_args[@]}" >/dev/null
else
    nohup code-server "${code_server_args[@]}" >"${LAB_CODE_SERVER_LOG:-/var/log/code-server.log}" 2>&1 </dev/null &
fi
deadline=$((SECONDS + 30))
until bounded 3 curl -s -o /dev/null "http://127.0.0.1:${CODE_SERVER_PORT}/"; do
    if [ "$SECONDS" -ge "$deadline" ]; then
        log "WARNING: code-server does not answer on port ${CODE_SERVER_PORT} yet (journalctl -u code-server-lab)"
        break
    fi
    sleep 1
done
log "code-server listening on port ${CODE_SERVER_PORT} (${SECONDS}s since start)"

# The Dev Dashboard tab: Diagrid's Dapr Dev Dashboard (github.com/diagridio/dev-dashboard), a live
# view of the apps, sidecars, workflows and logs learners start with `dapr run`. The sandbox image
# installs it (pinned in modules/dapr-sandbox/versions.hcl); run it as a transient systemd unit.
# It binds 0.0.0.0 so Instruqt's service proxy can reach it; in this (host) mode it only accepts a
# loopback Host header, which the service tab sends (see tabs.hcl).
DEV_DASHBOARD_PORT=9090
command -v diagrid-dev-dashboard >/dev/null 2>&1 ||
    die "the Dapr Dev Dashboard is not installed; the sandbox image (modules/dapr-sandbox) should provide it."
dev_dashboard_args=(--port "$DEV_DASHBOARD_PORT" --bind 0.0.0.0 --no-open --mode dapr-run)
if command -v systemd-run >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
    systemctl stop dev-dashboard-lab >/dev/null 2>&1 || true
    systemd-run --unit=dev-dashboard-lab --property=Restart=always \
        --setenv=HOME="$HOME" --setenv=PATH="$PATH" \
        "$(command -v diagrid-dev-dashboard)" "${dev_dashboard_args[@]}" >/dev/null
else
    nohup diagrid-dev-dashboard "${dev_dashboard_args[@]}" >"${LAB_DEV_DASHBOARD_LOG:-/var/log/dev-dashboard.log}" 2>&1 </dev/null &
fi
deadline=$((SECONDS + 30))
until bounded 3 curl -s -o /dev/null -H "Host: localhost:${DEV_DASHBOARD_PORT}" "http://127.0.0.1:${DEV_DASHBOARD_PORT}/"; do
    if [ "$SECONDS" -ge "$deadline" ]; then
        log "WARNING: the Dev Dashboard does not answer on port ${DEV_DASHBOARD_PORT} yet (journalctl -u dev-dashboard-lab)"
        break
    fi
    sleep 1
done
log "Dapr Dev Dashboard listening on port ${DEV_DASHBOARD_PORT} (${SECONDS}s since start)"

# `dapr init` is skipped when the containers are already running, so a re-run does not tear down
# and re-create them.
dapr_containers_running() {
    [ -n "$(bounded 10 docker ps -f "name=dapr_placement" -f "status=running" -q)" ] &&
        [ -n "$(bounded 10 docker ps -f "name=dapr_scheduler" -f "status=running" -q)" ] &&
        [ -n "$(bounded 10 docker ps -f "name=dapr_redis" -f "status=running" -q)" ]
}
if dapr_containers_running; then
    log "Dapr containers already running"
else
    log "dapr init --runtime-version $DAPR_RUNTIME_VERSION"
    bounded 240 dapr init --runtime-version "$DAPR_RUNTIME_VERSION" ||
        die "dapr init failed or did not finish within 240 seconds."
    log "dapr init done (${SECONDS}s since start)"
fi

