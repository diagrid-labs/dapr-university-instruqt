#!/usr/bin/env bash
set -euo pipefail

export DOTNET_SDK_CHANNEL=10.0
export JAVA_VERSION=17
export NODE_MAJOR=24
export DAPR_CLI_VERSION=1.19.1
export CODE_SERVER_VERSION=4.145.2
export DEV_DASHBOARD_VERSION=0.0.27
export JQ_VERSION=1.8.1
export PREWARM_DAPR_RUNTIME_VERSION=1.19.2

# ---- install-tools.sh ----
# Installs the sandbox toolchain on Ubuntu 24.04 (x86_64). Run inside an Instruqt Image Builder
# session via the output of render-image-script.sh, which exports the pinned versions from
# versions.hcl first. Keep it in sync with what the lab setup scripts and assignments assume
# is already installed:
#
#   Docker Engine     `dapr init` containers and any container a lab starts itself
#   Dapr CLI          every challenge runs `dapr run -f .`
#   .NET SDK          the dotnet demos
#   JDK + Maven       the java demos (Spring Boot, started with `mvn spring-boot:run`)
#   Python + uv       the python demos (started with `uv run python app.py`); lab setup also
#                     uses python3 for small scripting jobs
#   Node.js + npm     tooling some labs need
#   jq                labs pipe curl output through it
#   git               lab setup scripts clone the demo repo
#   code-server       VS Code in the browser, the labs' Editor tab (started by lab setup)
#   Dev Dashboard     Diagrid's Dapr Dev Dashboard, the labs' Dev Dashboard tab (started by lab
#                     setup)
#
# Container images are pulled by prewarm.sh, but never initialised or started here: the Image
# Builder saves the state of a running Docker daemon into the image.

set -euo pipefail

missing=0
for var in DOTNET_SDK_CHANNEL JAVA_VERSION NODE_MAJOR DAPR_CLI_VERSION CODE_SERVER_VERSION DEV_DASHBOARD_VERSION JQ_VERSION; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: required environment variable $var is not set" >&2
        missing=1
    fi
done
if [ "$missing" -ne 0 ]; then
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
# software-properties-common provides add-apt-repository, used for the .NET PPA below.
sudo apt-get install -y ca-certificates curl wget git unzip software-properties-common

# Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# .NET SDK. Ubuntu 24.04 carries .NET 8 in its own feed, so the backports PPA has the newer ones.
sudo add-apt-repository -y ppa:dotnet/backports
sudo apt-get update
sudo apt-get install -y "dotnet-sdk-$DOTNET_SDK_CHANNEL"

# Java + Maven
sudo apt-get install -y "openjdk-$JAVA_VERSION-jdk" maven

# Python. 3.12 is the default on Ubuntu 24.04; venv and pip are separate packages there.
sudo apt-get install -y python3 python3-venv python3-pip

# uv, installed into /usr/local/bin rather than $HOME/.local/bin: the python demos are started by
# the Dapr CLI with `command: ["uv", "run", "python", "app.py"]`, so uv has to resolve on the
# default PATH of every terminal tab, not only in a shell that a setup script has extended.
curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR=/usr/local/bin sh
# Belt and braces: if that installer ever stops honouring UV_INSTALL_DIR and falls back to
# $HOME/.local/bin, link it onto the default PATH anyway.
if ! command -v uv >/dev/null 2>&1 && [ -x "$HOME/.local/bin/uv" ]; then
    sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
    sudo ln -sf "$HOME/.local/bin/uvx" /usr/local/bin/uvx
fi

# Node.js via NodeSource (the distro package is far behind the LTS line)
curl -fsSL "https://deb.nodesource.com/setup_$NODE_MAJOR.x" | sudo -E bash -
sudo apt-get install -y nodejs

# Dapr CLI, pinned
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash -s "$DAPR_CLI_VERSION"

# code-server (VS Code in the browser), pinned. The standalone release unpacks into /opt; the
# binary is linked onto the default PATH. Lab setup starts it, the image only installs it.
cs_archive="code-server-${CODE_SERVER_VERSION}-linux-amd64"
curl -fsSL -o "/tmp/${cs_archive}.tar.gz" \
    "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/${cs_archive}.tar.gz"
sudo tar -xzf "/tmp/${cs_archive}.tar.gz" -C /opt
sudo ln -sf "/opt/${cs_archive}/bin/code-server" /usr/local/bin/code-server
rm -f "/tmp/${cs_archive}.tar.gz"

# Diagrid Dapr Dev Dashboard, pinned. A single binary in the release archive.
dd_archive="diagrid-dev-dashboard_${DEV_DASHBOARD_VERSION}_linux_amd64"
curl -fsSL -o "/tmp/${dd_archive}.tar.gz" \
    "https://github.com/diagridio/dev-dashboard/releases/download/v${DEV_DASHBOARD_VERSION}/${dd_archive}.tar.gz"
sudo mkdir -p "/opt/${dd_archive}"
sudo tar -xzf "/tmp/${dd_archive}.tar.gz" -C "/opt/${dd_archive}"
sudo ln -sf "/opt/${dd_archive}/diagrid-dev-dashboard" /usr/local/bin/diagrid-dev-dashboard
rm -f "/tmp/${dd_archive}.tar.gz"

# jq, pinned static binary (the distro package lags behind).
case "$(uname -m)" in
    x86_64) jq_arch=amd64 ;;
    aarch64 | arm64) jq_arch=arm64 ;;
    *) echo "ERROR: unsupported architecture $(uname -m) for jq" >&2; exit 1 ;;
esac
sudo curl -fsSL -o /usr/local/bin/jq \
    "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${jq_arch}"
sudo chmod 0755 /usr/local/bin/jq

# Fail the image build loudly if anything above did not land, instead of at a learner's first
# `dapr run`.
echo "--- versions ---"
for cmd in docker dapr dotnet java mvn python3 uv node npm git jq code-server diagrid-dev-dashboard; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd is not installed" >&2
        exit 1
    fi
done
docker --version
dapr -v
dotnet --version
java -version
mvn --version
python3 --version
uv --version
node --version
npm --version
git --version
jq --version
code-server --version | grep -m1 -E '^[0-9]+\.'
diagrid-dev-dashboard --version

# ---- prewarm.sh ----
# Warms caches inside the sandbox image: package caches (~/.nuget, ~/.m2, uv's cache, ~/.npm) and the
# container images `dapr init` and the secrets labs pull. Runs after install-tools.sh in the
# Image Builder session. Never runs `dapr init` or starts a container: the Image Builder saves
# the state of running services into the image.
#
# Needs PREWARM_DAPR_RUNTIME_VERSION (rendered from versions.hcl). Failures to clone or pull are
# warnings: the sandbox still works, it is just slower on first use. A failing package build is
# fatal (set -e) on purpose, so a broken image is noticed while it is being built.

set -euo pipefail

: "${PREWARM_DAPR_RUNTIME_VERSION:?PREWARM_DAPR_RUNTIME_VERSION is not set}"

# Images that `dapr init` (Dapr 1.19) pulls: the runtime image also serves placement and
# scheduler, plus Redis and Zipkin. Vault is started by the secrets lab, RabbitMQ by the pubsub lab,
# Postgres by the bindings lab.
PREWARM_IMAGES=(
    "daprio/dapr:$PREWARM_DAPR_RUNTIME_VERSION"
    "redis:6"
    "openzipkin/zipkin"
    "hashicorp/vault:1.20"
    "rabbitmq:4.4.0-management"
    "postgres:18.7"
)

# Container images, only if a Docker daemon is up.
if docker info >/dev/null 2>&1; then
    for image in "${PREWARM_IMAGES[@]}"; do
        docker pull "$image" || echo "WARNING: could not pull $image" >&2
    done
else
    echo "WARNING: Docker daemon is not reachable, skipping container image pre-pull." >&2
fi

# Package caches. Without this, the first `dapr run` of each language in the sandbox pays a full
# cold restore, which is minutes of a 30-minute lab. Only the caches are kept; the checkout
# itself is thrown away because lab setup clones the repo fresh at launch.
PREWARM_DIR="$(mktemp -d)"
trap 'rm -rf "$PREWARM_DIR"' EXIT
if git clone --depth 1 https://github.com/diagrid-labs/university-labs.git "$PREWARM_DIR/repo"; then
    SECRETS_BASE="$PREWARM_DIR/repo/secrets"
    # The swap demo (demo 3) holds no application code (it runs the demo 1 app against another
    # secret store), so warming demo 1 and the two scoping apps covers all challenges. Folder
    # names follow each language: PascalCase for .NET, kebab-case for Python and Java.
    for demo in Demo1-ReadSecret Demo2-Scoping/AppA Demo2-Scoping/AppB; do
        (cd "$SECRETS_BASE/dotnet/$demo" && dotnet build)
    done
    for demo in demo1-read-secret demo2-scoping/app-a demo2-scoping/app-b; do
        (cd "$SECRETS_BASE/python/$demo" && uv sync)
        (cd "$SECRETS_BASE/java/$demo" && mvn -q -DskipTests package)
    done

    # Pubsub demos 1 to 5 (demo 6 swaps the broker and holds no code). Every app folder, in all
    # three languages: PascalCase for .NET, kebab-case for Python and Java.
    REPO_DIR="$PREWARM_DIR/repo"
    for app in \
        pubsub/dotnet/Demo1-Subscriptions/OrderApi \
        pubsub/dotnet/Demo1-Subscriptions/Shipping \
        pubsub/dotnet/Demo1-Subscriptions/Invoicing \
        pubsub/dotnet/Demo2-Streaming/OrderApi \
        pubsub/dotnet/Demo2-Streaming/Warehouse \
        pubsub/dotnet/Demo3-CloudEvents/OrderApi \
        pubsub/dotnet/Demo3-CloudEvents/Shipping \
        pubsub/dotnet/Demo4-Bulk/OrderApi \
        pubsub/dotnet/Demo4-Bulk/Shipping \
        pubsub/dotnet/Demo5-RoutingDeadLetter/OrderApi \
        pubsub/dotnet/Demo5-RoutingDeadLetter/Shipping; do
        (cd "$REPO_DIR/$app" && dotnet build)
    done
    for app in \
        pubsub/python/demo1-subscriptions/order-api \
        pubsub/python/demo1-subscriptions/shipping \
        pubsub/python/demo1-subscriptions/invoicing \
        pubsub/python/demo2-streaming/order-api \
        pubsub/python/demo2-streaming/warehouse \
        pubsub/python/demo3-cloud-events/order-api \
        pubsub/python/demo3-cloud-events/shipping \
        pubsub/python/demo4-bulk/order-api \
        pubsub/python/demo4-bulk/shipping \
        pubsub/python/demo5-routing-dead-letter/order-api \
        pubsub/python/demo5-routing-dead-letter/shipping; do
        (cd "$REPO_DIR/$app" && uv sync)
    done
    for app in \
        pubsub/java/demo1-subscriptions/order-api \
        pubsub/java/demo1-subscriptions/shipping \
        pubsub/java/demo1-subscriptions/invoicing \
        pubsub/java/demo2-streaming/order-api \
        pubsub/java/demo2-streaming/warehouse \
        pubsub/java/demo3-cloud-events/order-api \
        pubsub/java/demo3-cloud-events/shipping \
        pubsub/java/demo4-bulk/order-api \
        pubsub/java/demo4-bulk/shipping \
        pubsub/java/demo5-routing-dead-letter/order-api \
        pubsub/java/demo5-routing-dead-letter/shipping; do
        (cd "$REPO_DIR/$app" && mvn -q -DskipTests package)
    done

    # Bindings demos 1 to 4. Every demo has an engineering app; demo 4 adds the subspace beacon.
    for app in \
        bindings/dotnet/Demo1-CronTrigger/Engineering \
        bindings/dotnet/Demo2-PostgresOutput/Engineering \
        bindings/dotnet/Demo3-StateVsBinding/Engineering \
        bindings/dotnet/Demo4-SubspaceBeacon/Engineering \
        bindings/dotnet/Demo4-SubspaceBeacon/SubspaceBeacon; do
        (cd "$REPO_DIR/$app" && dotnet build)
    done
    for app in \
        bindings/python/demo1-cron-trigger/engineering \
        bindings/python/demo2-postgres-output/engineering \
        bindings/python/demo3-state-vs-binding/engineering \
        bindings/python/demo4-subspace-beacon/engineering \
        bindings/python/demo4-subspace-beacon/subspace-beacon; do
        (cd "$REPO_DIR/$app" && uv sync)
    done
    for app in \
        bindings/java/demo1-cron-trigger/engineering \
        bindings/java/demo2-postgres-output/engineering \
        bindings/java/demo3-state-vs-binding/engineering \
        bindings/java/demo4-subspace-beacon/engineering \
        bindings/java/demo4-subspace-beacon/subspace-beacon; do
        (cd "$REPO_DIR/$app" && mvn -q -DskipTests package)
    done

    # Workflow demos 1 to 6. Each demo has one engineering app, in all four languages: PascalCase
    # for .NET, kebab-case for Python, Java and TypeScript. `npm ci` fills npm's cache (~/.npm), so
    # the lab's own `npm ci` at launch installs from it.
    for spec in \
        Demo1-DurableExecution:demo1-durable-execution \
        Demo2-TaskChaining:demo2-task-chaining \
        Demo3-FanOutFanIn:demo3-fan-out-fan-in \
        Demo4-Monitor:demo4-monitor \
        Demo5-HumanInTheLoop:demo5-human-in-the-loop \
        Demo6-Management:demo6-management; do
        dotnet_demo="${spec%%:*}"
        demo="${spec#*:}"
        (cd "$REPO_DIR/workflow/dotnet/$dotnet_demo/Engineering" && dotnet build)
        (cd "$REPO_DIR/workflow/python/$demo/engineering" && uv sync)
        (cd "$REPO_DIR/workflow/java/$demo/engineering" && mvn -q -DskipTests package)
        (cd "$REPO_DIR/workflow/typescript/$demo/engineering" && npm ci)
    done
else
    echo "WARNING: could not clone the demo repo, so the package caches are cold. The sandbox" >&2
    echo "will still work, but the first build of each language will be slow." >&2
fi


# ---- install sandbox-setup.sh ----
mkdir -p /usr/local/lib/dapr-sandbox
cat > /usr/local/lib/dapr-sandbox/sandbox-setup.sh <<'SANDBOX_SETUP_EOF'
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
export TRACKS_SRC_DIR="$HOME/university-labs"
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

SANDBOX_SETUP_EOF
chmod 0755 /usr/local/lib/dapr-sandbox/sandbox-setup.sh
