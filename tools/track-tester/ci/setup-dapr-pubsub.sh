#!/usr/bin/env bash
# Reproduce the dapr-pubsub sandbox environment in CI (and locally).
# Mirrors dapr-pubsub/_setup/sandbox-setup.sh: clone the demo source, install the
# Dapr CLI, and `dapr init` (which starts the dapr_redis container every demo
# publishes to). The .NET 10 SDK is provided by the workflow's setup-dotnet step.
set -euo pipefail

PUBSUB_DIR="${PUBSUB_DIR:-$HOME/dapr-pub-sub-deep-dive}"

# 1. Install uv (used to run robot).
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# 2. Clone the demo source the suites build and run.
if [ ! -d "$PUBSUB_DIR" ]; then
  git clone https://github.com/diagrid-labs/dapr-pub-sub-deep-dive.git "$PUBSUB_DIR"
fi

# 3. Install the Dapr CLI from master (matching the track's _setup, which does
#    not pin a version) and initialise Dapr.
if ! command -v dapr >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash
fi
dapr uninstall --all >/dev/null || true
dapr init

echo "Setup complete. PUBSUB_DIR=$PUBSUB_DIR"
