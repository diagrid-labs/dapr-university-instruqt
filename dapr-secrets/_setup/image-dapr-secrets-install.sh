# Base image is the Instruqt docker image.
# Host is Ubuntu 24.04
# Shell = bash
#
# This script builds the base VM image once. Keep it in sync with the tools that
# _setup/sandbox-setup.sh, the per-challenge scripts/setup.sh and the assignments assume are
# already there:
#
#   Docker Engine     `dapr init` containers, and the hashicorp/vault container of challenge 4
#   Dapr CLI          every challenge runs `dapr run -f .`
#   .NET 10 SDK       the dotnet demos target net10.0
#   JDK 17 + Maven    the java demos are Spring Boot 3.4.5 with <java.version>17</java.version>
#                     and start with `mvn spring-boot:run`
#   Python 3.12 + uv  the python demos require >=3.12 and start with `uv run python app.py`;
#                     sandbox-setup.sh also uses python3 to seed Vault from secrets.json
#   git               sandbox-setup.sh and every scripts/setup.sh clone the demo repo
#
# The container images themselves are pulled at sandbox launch (`dapr init` and the `docker run`
# of Vault in sandbox-setup.sh), not here, because the Docker daemon is not guaranteed to be up
# during an image build.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
# software-properties-common provides add-apt-repository, used for the .NET 10 PPA below.
sudo apt-get install -y ca-certificates curl wget git unzip software-properties-common

# Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# .NET 10 SDK. Ubuntu 24.04 carries .NET 8 in its own feed, so the backports PPA is what has 10.
sudo add-apt-repository -y ppa:dotnet/backports
sudo apt-get update
sudo apt-get install -y dotnet-sdk-10.0

# Java 17 + Maven
sudo apt-get install -y openjdk-17-jdk maven

# Python. 3.12 is the default on Ubuntu 24.04; venv and pip are separate packages there.
sudo apt-get install -y python3 python3-venv python3-pip

# uv, installed into /usr/local/bin rather than $HOME/.local/bin: the python demos are started by
# the Dapr CLI with `command: ["uv", "run", "python", "app.py"]`, so uv has to resolve on the
# default PATH of every terminal tab, not only in a shell that sandbox-setup.sh has extended.
curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR=/usr/local/bin sh
# Belt and braces: if that installer ever stops honouring UV_INSTALL_DIR and falls back to
# $HOME/.local/bin, link it onto the default PATH anyway.
if ! command -v uv >/dev/null 2>&1 && [ -x "$HOME/.local/bin/uv" ]; then
    sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
    sudo ln -sf "$HOME/.local/bin/uvx" /usr/local/bin/uvx
fi

# Dapr CLI. Deliberately unpinned, like the CI setup script: the track asserts what a learner
# gets today. When this image is rebuilt, re-check the pinned DAPR_CLI_VERSION and
# DAPR_RUNTIME_VERSION in sandbox-setup.sh — ci/setup-dapr-secrets.sh parses them out of that
# file and the CI runtime guard turns red on a minor bump.
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash

# Warm the package caches (~/.nuget, ~/.m2, uv's cache) by building every demo once. Without
# this, the first `dapr run` of each language in the sandbox pays a full cold restore, which is
# minutes of a 30-minute track. Only the caches are kept; the checkout itself is thrown away,
# because sandbox-setup.sh clones the repo fresh at launch.
PREWARM_DIR="$(mktemp -d)"
if git clone --depth 1 https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git "$PREWARM_DIR/repo"; then
    SECRETS_BASE="$PREWARM_DIR/repo/secrets"
    # Demo3-SwapProvider holds no application code — it runs Demo1-ReadSecret against another
    # secret store — so warming Demo1 and the two scoping apps covers all three challenges.
    for demo in Demo1-ReadSecret Demo2-Scoping/AppA Demo2-Scoping/AppB; do
        (cd "$SECRETS_BASE/dotnet/$demo" && dotnet build)
        (cd "$SECRETS_BASE/python/$demo" && uv sync)
        (cd "$SECRETS_BASE/java/$demo" && mvn -q -DskipTests package)
    done
else
    echo "WARNING: could not clone the demo repo, so the package caches are cold. The sandbox" >&2
    echo "will still work, but the first build of each language will be slow." >&2
fi
rm -rf "$PREWARM_DIR"

# Fail the image build loudly if anything above did not land, instead of at a learner's first
# `dapr run`.
echo "--- versions ---"
docker --version
dapr -v
dotnet --version
java -version
mvn --version
python3 --version
uv --version
git --version
