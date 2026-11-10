#!/usr/bin/env bash
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
#
# Container images are pulled by prewarm.sh, but never initialised or started here: the Image
# Builder saves the state of a running Docker daemon into the image.

set -euo pipefail

missing=0
for var in DOTNET_SDK_CHANNEL JAVA_VERSION NODE_MAJOR DAPR_CLI_VERSION; do
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

# Fail the image build loudly if anything above did not land, instead of at a learner's first
# `dapr run`.
echo "--- versions ---"
for cmd in docker dapr dotnet java mvn python3 uv node npm git; do
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
