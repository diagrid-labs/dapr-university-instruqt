#!/usr/bin/env bash
# Reproduce the dapr-101 sandbox environment in CI by reusing the real _setup scripts.
# Instruqt-only bits (agent variable set, docker login) are adapted/omitted here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SETUP_DIR="$REPO_ROOT/dapr-101/_setup"
QUICKSTARTS_DIR="${QUICKSTARTS_DIR:-$HOME/quickstarts}"

# 1. Parse the pinned Dapr version (single source of truth) and export it for the suites.
# awk is used (not grep -oP) so this runs on both macOS/BSD and GNU/Linux. The lines look like
# `agent variable set DAPR_CLI_VERSION 1.18.0`, so the version is the last field ($NF).
# These are the EXPECTED MINOR floor for challenge 2's assertion, not an install pin (see
# step 4); only their MAJOR.MINOR is asserted, so the patch digit here needn't track releases.
DAPR_CLI_VERSION="$(awk '/DAPR_CLI_VERSION/ {print $NF}' "$SETUP_DIR/sandbox-setup.sh")"
DAPR_RUNTIME_VERSION="$(awk '/DAPR_RUNTIME_VERSION/ {print $NF}' "$SETUP_DIR/sandbox-setup.sh")"
echo "DAPR_CLI_VERSION=$DAPR_CLI_VERSION"     >> "${GITHUB_ENV:-/dev/stdout}"
echo "DAPR_RUNTIME_VERSION=$DAPR_RUNTIME_VERSION" >> "${GITHUB_ENV:-/dev/stdout}"

# 2. Clone the quickstarts repo (drift source of truth).
if [ ! -d "$QUICKSTARTS_DIR/.git" ]; then
  git clone --depth 1 https://github.com/dapr/quickstarts.git "$QUICKSTARTS_DIR"
fi

# 3. Install uv (used by the Python quickstarts and to run robot).
# curl (not wget) so this runs on macOS too — macOS ships curl but not wget.
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# 4. Install the Dapr CLI and initialize Dapr exactly as assignment.md tells the learner to:
# the unpinned install script from `master`, then a bare `dapr init`.
#
# Deliberately NOT pinned to $DAPR_CLI_VERSION / $DAPR_RUNTIME_VERSION. Pinning made challenge
# 2's version assertion self-fulfilling - it could only prove this script did what it was told,
# never that the assignment's stated output is still true. It also mis-failed: the CI runner
# ships its own `dapr` earlier on PATH, so a pinned reinstall into /usr/local/bin stayed
# shadowed and the CLI line never matched the pin, while `--runtime-version` did apply -
# producing a CLI/runtime version mismatch no learner would ever see.
# Unpinned, the suites assert what a learner following the assignment actually gets, and
# challenge 2 fails exactly when Dapr's MAJOR.MINOR moves past the pinned one - the point at
# which sandbox-setup.sh's Instruqt variables and the assignment's expected output need updating.
#
# An existing `dapr` is left alone rather than reinstalled, so local runs use the CLI already on
# PATH (the version assertion is then a real signal about that CLI, and there is no
# reinstall-into-a-shadowed-path loop). See README "Local development on macOS".
if ! command -v dapr >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash
fi
dapr uninstall --all >/dev/null || true
dapr init

echo "Setup complete. QUICKSTARTS_DIR=$QUICKSTARTS_DIR, expecting Dapr ${DAPR_CLI_VERSION%.*}.x"
dapr --version
