#!/usr/bin/env bash
# Reproduce the dapr-workflow sandbox environment in CI.
# Mirrors ci/setup-dapr-101.sh, but the dapr-workflow track installs the Dapr CLI
# from master (its _setup/sandbox-setup.sh does not pin a version), so there is no
# version pin here. Language runtimes are provisioned by the workflow's
# setup-dotnet/setup-java steps, not by this script.
set -euo pipefail

QUICKSTARTS_DIR="${QUICKSTARTS_DIR:-$HOME/quickstarts}"

# 1. Clone the quickstarts repo (drift source of truth).
if [ ! -d "$QUICKSTARTS_DIR/.git" ]; then
  git clone --depth 1 https://github.com/dapr/quickstarts.git "$QUICKSTARTS_DIR"
fi

# 2. Install uv (used to run robot).
# curl (not wget) so this runs on macOS too — macOS ships curl but not wget.
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# 3. Install the Dapr CLI (latest master, matching the track's sandbox-setup.sh) and init.
# curl (not wget) for macOS portability, consistent with the uv step and setup-dapr-101.sh.
if ! command -v dapr >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash
fi
dapr uninstall --all >/dev/null || true
dapr init

echo "Setup complete. QUICKSTARTS_DIR=$QUICKSTARTS_DIR"
