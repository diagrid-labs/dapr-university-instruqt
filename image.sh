#!/usr/bin/env bash
set -euo pipefail

export DOTNET_SDK_CHANNEL=10.0
export JAVA_VERSION=17
export NODE_MAJOR=24
export DAPR_CLI_VERSION=1.19.1
export CODE_SERVER_VERSION=4.145.2
export DEV_DASHBOARD_VERSION=0.0.27
export PREWARM_DAPR_RUNTIME_VERSION=1.19.1

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
#   git               lab setup scripts clone the demo repo
#   code-server       VS Code in the browser, the labs' Editor tab (started by lab setup)
#   Dev Dashboard     Diagrid's Dapr Dev Dashboard, the labs' Dev Dashboard tab (started by lab
#                     setup)
#
# Container images are pulled by prewarm.sh, but never initialised or started here: the Image
# Builder saves the state of a running Docker daemon into the image.

set -euo pipefail

missing=0
for var in DOTNET_SDK_CHANNEL JAVA_VERSION NODE_MAJOR DAPR_CLI_VERSION CODE_SERVER_VERSION DEV_DASHBOARD_VERSION; do
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

# Fail the image build loudly if anything above did not land, instead of at a learner's first
# `dapr run`.
echo "--- versions ---"
for cmd in docker dapr dotnet java mvn python3 uv node npm git code-server diagrid-dev-dashboard; do
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
code-server --version | grep -m1 -E '^[0-9]+\.'
diagrid-dev-dashboard --version

# ---- prewarm.sh ----
# Warms caches inside the sandbox image: package caches (~/.nuget, ~/.m2, uv's cache) and the
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
# scheduler, plus Redis and Zipkin. Vault is started by the secrets lab.
DAPR_IMAGES=(
    "daprio/dapr:$PREWARM_DAPR_RUNTIME_VERSION"
    "redis:6"
    "openzipkin/zipkin"
    "hashicorp/vault:1.20"
)

# Container images, only if a Docker daemon is up.
if docker info >/dev/null 2>&1; then
    for image in "${DAPR_IMAGES[@]}"; do
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
if git clone --depth 1 https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git "$PREWARM_DIR/repo"; then
    SECRETS_BASE="$PREWARM_DIR/repo/secrets"
    # Demo3-SwapProvider holds no application code (it runs Demo1-ReadSecret against another
    # secret store), so warming Demo1 and the two scoping apps covers all challenges.
    for demo in Demo1-ReadSecret Demo2-Scoping/AppA Demo2-Scoping/AppB; do
        (cd "$SECRETS_BASE/dotnet/$demo" && dotnet build)
        (cd "$SECRETS_BASE/python/$demo" && uv sync)
        (cd "$SECRETS_BASE/java/$demo" && mvn -q -DskipTests package)
    done
else
    echo "WARNING: could not clone the demo repo, so the package caches are cold. The sandbox" >&2
    echo "will still work, but the first build of each language will be slow." >&2
fi

