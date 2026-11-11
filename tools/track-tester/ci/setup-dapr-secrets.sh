#!/usr/bin/env bash
# Reproduce the dapr-secrets lab environment in CI: same pins, same demo checkout, same Vault
# seeding library as dapr-secrets/scripts/lab-setup.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LAB_DIR="$REPO_ROOT/dapr-secrets"
READ_PIN="$REPO_ROOT/tools/track-tester/ci/read_pin.py"
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-$HOME/ai-agent-tracks-instruqt}"

# 0. Syntax-check the lab scripts. CI cannot run lab-setup.sh (it inits Dapr on the VM) and runs
# only its own sequence below, so this is the one CI signal that a bad edit to either script
# would otherwise kill the lab at launch.
bash -n "$LAB_DIR/scripts/seed-vault.sh"
bash -n "$LAB_DIR/scripts/lab-setup.sh"

# 1. Read the pins (single source of truth, see read_pin.py) and export them for the suites.
DAPR_CLI_VERSION="$(python3 "$READ_PIN" "$REPO_ROOT/modules/dapr-sandbox/versions.hcl" dapr_cli_version)"
DAPR_RUNTIME_VERSION="$(python3 "$READ_PIN" "$LAB_DIR/versions.hcl" dapr_runtime_version)"
TRACKS_SRC_REF="$(python3 "$READ_PIN" "$LAB_DIR/versions.hcl" tracks_src_ref)"
echo "DAPR_CLI_VERSION=$DAPR_CLI_VERSION"     >> "${GITHUB_ENV:-/dev/stdout}"
echo "DAPR_RUNTIME_VERSION=$DAPR_RUNTIME_VERSION" >> "${GITHUB_ENV:-/dev/stdout}"
echo "TRACKS_SRC_REF=$TRACKS_SRC_REF" >> "${GITHUB_ENV:-/dev/stdout}"
echo "TRACKS_SRC_DIR=$TRACKS_SRC_DIR" >> "${GITHUB_ENV:-/dev/stdout}"

# 2. Clone the demo repo (source of truth for the demo apps and resources) at the pinned commit.
# -e, not -d: in a git worktree the .git entry is a file, not a directory. Full clone: a commit
# SHA cannot be checked out of a shallow one.
if [ ! -e "$TRACKS_SRC_DIR/.git" ]; then
  git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git "$TRACKS_SRC_DIR"
  git -C "$TRACKS_SRC_DIR" checkout "$TRACKS_SRC_REF"
  # Only checked after our own clone: a pre-existing checkout (actions/checkout) is already pinned.
  if [ "$(git -C "$TRACKS_SRC_DIR" rev-parse HEAD)" != "$TRACKS_SRC_REF" ]; then
    echo "WARNING: $TRACKS_SRC_DIR is at $(git -C "$TRACKS_SRC_DIR" rev-parse HEAD), not the pinned ref $TRACKS_SRC_REF." >&2
  fi
fi

# 3. Install uv (used by the Python demos and to run robot).
# curl (not wget) so this runs on macOS too - macOS ships curl but not wget.
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# jq: the challenge 2 suite runs the assignment's `curl -s ... | jq` commands. GitHub's Ubuntu
# runners ship it; on the VM, dapr-secrets/scripts/lab-setup.sh downloads it.
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is not installed (brew install jq / apt-get install jq)." >&2
  exit 1
fi

# 4. Install the Dapr CLI and initialize Dapr exactly as the assignments tell the learner to:
# the unpinned install script from `master`, then a bare `dapr init`.
#
# Deliberately NOT pinned to $DAPR_CLI_VERSION / $DAPR_RUNTIME_VERSION, for the same reason as
# setup-dapr-101.sh: a pinned install could only prove this script did what it was told, and a
# runner's own `dapr` earlier on PATH would shadow it. Unpinned, the suites assert what a learner
# gets, and challenge 3's DENIED_* / MISSING_* assertions fail exactly when a Dapr release
# changes the (undocumented) secret-denial wording - the signal to update the variables file
# and the assignment.
#
# Unlike setup-dapr-101.sh there is no `dapr uninstall --all` first: that would wipe containers
# on a developer machine, and `dapr init` is skipped if the containers are already running so
# this script stays idempotent.
if ! command -v dapr >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash
fi
if [ -z "$(docker ps -f "name=dapr_placement" -f "status=running" -q)" ] || \
   [ -z "$(docker ps -f "name=dapr_scheduler" -f "status=running" -q)" ] || \
   [ -z "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
  dapr init
fi

# 5. Write secrets.json from the committed template (the single owner of the secret values) and
# start + seed Vault with the same library the lab setup uses.
if [ ! -f "$TRACKS_SRC_DIR/secrets/secrets.example.json" ]; then
  echo "ERROR: $TRACKS_SRC_DIR/secrets/secrets.example.json not found. Is $TRACKS_SRC_DIR a current clone of diagrid-labs/ai-agent-tracks-instruqt?" >&2
  exit 1
fi
cp "$TRACKS_SRC_DIR/secrets/secrets.example.json" "$TRACKS_SRC_DIR/secrets/secrets.json"
# shellcheck source=/dev/null
source "$LAB_DIR/scripts/seed-vault.sh"
seed_vault "$TRACKS_SRC_DIR/secrets/secrets.json"

# 6. Fail loudly if the Dapr runtime that is actually running is not the pinned MAJOR.MINOR.
# Step 4 deliberately reuses an existing install (never uninstalls it), so an older runtime on a
# developer machine would otherwise pass silently and challenge 3's 403/500 assertions would run
# against the wrong runtime. Only MAJOR.MINOR is compared, as in setup-dapr-101.sh.
RUNNING_RUNTIME="$(dapr --version | awk '/Runtime version/ {print $NF}')"
if [ "${RUNNING_RUNTIME%.*}" != "${DAPR_RUNTIME_VERSION%.*}" ]; then
  echo "ERROR: running Dapr runtime is $RUNNING_RUNTIME but this track pins $DAPR_RUNTIME_VERSION (the runtime has moved past the pin, or an older one is running)." >&2
  echo "The secret-denial wording (403 ERR_PERMISSION_DENIED / 500 ERR_SECRET_GET) is version-sensitive, so the suites would assert against the wrong runtime. Run 'dapr uninstall --all && dapr init' (this removes your Dapr containers) and re-run." >&2
  exit 1
fi

echo "Setup complete. TRACKS_SRC_DIR=$TRACKS_SRC_DIR, expecting Dapr ${DAPR_CLI_VERSION%.*}.x"
dapr --version
