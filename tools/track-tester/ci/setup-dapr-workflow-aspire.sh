#!/usr/bin/env bash
# Reproduce the dapr-workflow-aspire sandbox environment in CI.
# The track builds the app live from the assignments, so there is no repo to
# clone. This script provisions the runtime bits the suite needs at test time:
# uv (to run robot), the Dapr CLI, and `dapr init` (the workflow state store
# points at the dapr_redis container it starts). .NET 10 + the Aspire CLI and
# project templates are installed by the workflow's own steps. The diagrid
# dashboard is NOT pulled — the suite does not run it.
set -euo pipefail

# 1. Install uv (used to run robot).
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# 2. Install the Dapr CLI from master (matching the track's _setup, which does
#    not pin a version) and initialise Dapr (starts dapr_redis etc.).
if ! command -v dapr >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash
fi
dapr uninstall --all >/dev/null || true
dapr init

echo "Setup complete."
