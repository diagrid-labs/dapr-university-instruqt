#!/usr/bin/env bash
# Reproduce the dapr-101 sandbox environment in CI by reusing the real _setup scripts.
# Instruqt-only bits (agent variable set, docker login) are adapted/omitted here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SETUP_DIR="$REPO_ROOT/dapr-101/_setup"
QUICKSTARTS_DIR="${QUICKSTARTS_DIR:-$HOME/quickstarts}"

# 1. Parse the pinned Dapr version (single source of truth) and export it for the suites.
# Note: grep -oP (PCRE) requires GNU grep — present on the Ubuntu CI runners this targets.
DAPR_CLI_VERSION="$(grep -oP 'DAPR_CLI_VERSION\s+\K[0-9.]+' "$SETUP_DIR/sandbox-setup.sh")"
DAPR_RUNTIME_VERSION="$(grep -oP 'DAPR_RUNTIME_VERSION\s+\K[0-9.]+' "$SETUP_DIR/sandbox-setup.sh")"
echo "DAPR_CLI_VERSION=$DAPR_CLI_VERSION"     >> "${GITHUB_ENV:-/dev/stdout}"
echo "DAPR_RUNTIME_VERSION=$DAPR_RUNTIME_VERSION" >> "${GITHUB_ENV:-/dev/stdout}"

# 2. Clone the quickstarts repo (drift source of truth).
if [ ! -d "$QUICKSTARTS_DIR/.git" ]; then
  git clone --depth 1 https://github.com/dapr/quickstarts.git "$QUICKSTARTS_DIR"
fi

# 3. Install uv (used by the Python quickstarts and to run robot).
if ! command -v uv >/dev/null 2>&1; then
  wget -qO- https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# 4. Install the Dapr CLI at the pinned version and initialize Dapr.
# Install/repin the Dapr CLI to the exact pinned version (not just "any dapr present").
current_cli="$(dapr --version 2>/dev/null | grep -oP 'CLI version:\s*\K[0-9.]+' || true)"
if [ "$current_cli" != "$DAPR_CLI_VERSION" ]; then
  wget -q "https://raw.githubusercontent.com/dapr/cli/v${DAPR_CLI_VERSION}/install/install.sh" -O - \
    | DAPR_INSTALL_VERSION="$DAPR_CLI_VERSION" /bin/bash
fi
dapr uninstall --all >/dev/null || true
dapr init --runtime-version "$DAPR_RUNTIME_VERSION"

echo "Setup complete. QUICKSTARTS_DIR=$QUICKSTARTS_DIR, Dapr $DAPR_CLI_VERSION"
