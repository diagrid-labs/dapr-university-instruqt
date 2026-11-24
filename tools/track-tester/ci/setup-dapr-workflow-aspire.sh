#!/usr/bin/env bash
# Reproduce the dapr-workflow-aspire lab environment in CI: same pins, same demo checkout as the lab
# (the shared boot setup lives in modules/dapr-sandbox/scripts/sandbox-setup.sh, the lab's own steps
# in dapr-workflow-aspire/scripts/lab-setup.sh). The learner builds the app from scratch in the
# demo repo's workflow-aspire/ folder; the suites rebuild it from the assignments. On top of the
# Dapr setup that the other 2.0 labs share, this installs the two tools the AppHost runs: the Aspire
# CLI at the lab's pin and the Dev Dashboard binary at the module's pin (the sandbox image has it).
# .NET 10 comes from the workflow's setup-dotnet step.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LAB_DIR="$REPO_ROOT/dapr-workflow-aspire"
READ_PIN="$REPO_ROOT/tools/track-tester/ci/read_pin.py"
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-$HOME/university-labs}"
# The Aspire CLI and the Dev Dashboard go here, not on a system path: no sudo, and a developer's
# own `aspire` (often another version) stays as it is. CI puts the folder first on PATH.
TOOLS_BIN="${ASPIRE_LAB_TOOLS_BIN:-$HOME/.aspire-lab/bin}"

# 0. Syntax-check the lab and module scripts. CI cannot run them (they set up the VM) and runs only
# its own sequence below, so this is the one CI signal that a bad edit to any of them would
# otherwise kill the lab at launch. (The pytest test_workflow_aspire_lab_setup.py runs lab-setup.sh
# with stubs.)
bash -n "$REPO_ROOT/modules/dapr-sandbox/scripts/sandbox-setup.sh"
for script in "$LAB_DIR"/scripts/*.sh; do
  bash -n "$script"
done

# 1. Read the pins (single source of truth, see read_pin.py) and export them for the suites.
DAPR_CLI_VERSION="$(python3 "$READ_PIN" "$REPO_ROOT/modules/dapr-sandbox/versions.hcl" dapr_cli_version)"
DEV_DASHBOARD_VERSION="$(python3 "$READ_PIN" "$REPO_ROOT/modules/dapr-sandbox/versions.hcl" dev_dashboard_version)"
DAPR_RUNTIME_VERSION="$(python3 "$READ_PIN" "$LAB_DIR/versions.hcl" dapr_runtime_version)"
TRACKS_SRC_REF="$(python3 "$READ_PIN" "$LAB_DIR/versions.hcl" tracks_src_ref)"
LAB_ASPIRE_CLI_VERSION="$(python3 "$READ_PIN" "$LAB_DIR/versions.hcl" aspire_cli_version)"
{
  echo "DAPR_CLI_VERSION=$DAPR_CLI_VERSION"
  echo "DAPR_RUNTIME_VERSION=$DAPR_RUNTIME_VERSION"
  echo "TRACKS_SRC_REF=$TRACKS_SRC_REF"
  echo "TRACKS_SRC_DIR=$TRACKS_SRC_DIR"
  echo "LAB_ASPIRE_CLI_VERSION=$LAB_ASPIRE_CLI_VERSION"
} >> "${GITHUB_ENV:-/dev/stdout}"

# 2. Clone the demo repo at the pinned commit. Its workflow-aspire/ folder is the (nearly empty)
# workspace the suites build the solution in. -e, not -d: in a git worktree the .git entry is a
# file, not a directory. Full clone: a commit SHA cannot be checked out of a shallow one.
if [ ! -e "$TRACKS_SRC_DIR/.git" ]; then
  git clone https://github.com/diagrid-labs/university-labs.git "$TRACKS_SRC_DIR"
  git -C "$TRACKS_SRC_DIR" checkout "$TRACKS_SRC_REF"
  # Only checked after our own clone: a pre-existing checkout (actions/checkout) is already pinned.
  if [ "$(git -C "$TRACKS_SRC_DIR" rev-parse HEAD)" != "$TRACKS_SRC_REF" ]; then
    echo "WARNING: $TRACKS_SRC_DIR is at $(git -C "$TRACKS_SRC_DIR" rev-parse HEAD), not the pinned ref $TRACKS_SRC_REF." >&2
  fi
fi
if [ ! -d "$TRACKS_SRC_DIR/workflow-aspire" ]; then
  echo "ERROR: $TRACKS_SRC_DIR/workflow-aspire not found. Is $TRACKS_SRC_DIR at $TRACKS_SRC_REF?" >&2
  exit 1
fi

# 3. Install uv (used to run robot).
# curl (not wget) so this runs on macOS too - macOS ships curl but not wget.
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# jq: the suites run the assignments' `curl -s ... | jq` commands. GitHub's Ubuntu
# runners ship it; on the VM, the sandbox image ships it (jq_version in modules/dapr-sandbox/versions.hcl).
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is not installed (brew install jq / apt-get install jq)." >&2
  exit 1
fi

# 4. The Aspire CLI at the lab's pin, with the same installer and flags as lab-setup.sh, into
# $TOOLS_BIN/../aspire with a symlink in $TOOLS_BIN. Skipped when that copy already has the pin.
mkdir -p "$TOOLS_BIN"
ASPIRE_DIR="$(dirname "$TOOLS_BIN")/aspire"
# Telemetry off before the first `aspire` call; the version is read from anywhere in the output,
# so a first-run notice on stdout does not break the check (as in lab-setup.sh).
export ASPIRE_CLI_TELEMETRY_OPTOUT=true
aspire_version() { { "$TOOLS_BIN/aspire" --version 2>/dev/null | grep -Eom1 '[0-9]+\.[0-9]+\.[0-9]+'; } || true; }
if [ "$(aspire_version)" != "$LAB_ASPIRE_CLI_VERSION" ]; then
  installer="$(mktemp)"
  curl -fsSL https://aspire.dev/install.sh -o "$installer"
  bash "$installer" --install-path "$ASPIRE_DIR" --version "$LAB_ASPIRE_CLI_VERSION" --skip-path
  rm -f "$installer"
  ln -sf "$ASPIRE_DIR/aspire" "$TOOLS_BIN/aspire"
fi
if [ "$(aspire_version)" != "$LAB_ASPIRE_CLI_VERSION" ]; then
  echo "ERROR: the Aspire CLI at $TOOLS_BIN/aspire is '$(aspire_version)', but the lab pins $LAB_ASPIRE_CLI_VERSION." >&2
  exit 1
fi

# 5. The Dev Dashboard binary at the module's pin: the AppHost starts `diagrid-dev-dashboard` as an
# executable resource, as the sandbox image provides it.
case "$(uname -s)" in
  Linux) dd_os=linux ;;
  Darwin) dd_os=darwin ;;
  *) echo "ERROR: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) dd_arch=amd64 ;;
  arm64|aarch64) dd_arch=arm64 ;;
  *) echo "ERROR: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac
dd_archive="diagrid-dev-dashboard_${DEV_DASHBOARD_VERSION}_${dd_os}_${dd_arch}"
DD_DIR="$(dirname "$TOOLS_BIN")/$dd_archive"
if [ ! -x "$DD_DIR/diagrid-dev-dashboard" ]; then
  mkdir -p "$DD_DIR"
  curl -fsSL "https://github.com/diagridio/dev-dashboard/releases/download/v${DEV_DASHBOARD_VERSION}/${dd_archive}.tar.gz" |
    tar -xz -C "$DD_DIR"
fi
ln -sf "$DD_DIR/diagrid-dev-dashboard" "$TOOLS_BIN/diagrid-dev-dashboard"

export PATH="$TOOLS_BIN:$PATH"
echo "$TOOLS_BIN" >> "${GITHUB_PATH:-/dev/null}"

# 6. Install the Dapr CLI and initialize Dapr exactly as a learner's sandbox has it: the unpinned
# install script from `master`, then a bare `dapr init` (the AppHost's state store component points
# at the dapr_redis container it starts).
#
# Deliberately NOT pinned to $DAPR_CLI_VERSION / $DAPR_RUNTIME_VERSION, for the same reason as
# setup-dapr-secrets.sh: a pinned install could only prove this script did what it was told, and a
# runner's own `dapr` earlier on PATH would shadow it. Unpinned, the suites assert what a learner
# gets.
#
# There is no `dapr uninstall --all` first: that would wipe containers on a developer machine,
# and `dapr init` is skipped if the containers are already running so this script stays idempotent.
if ! command -v dapr >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash
fi
if [ -z "$(docker ps -f "name=dapr_placement" -f "status=running" -q)" ] || \
   [ -z "$(docker ps -f "name=dapr_scheduler" -f "status=running" -q)" ] || \
   [ -z "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
  # Retries in CI when a container's host port is briefly taken on the runner (see dapr-init.sh).
  # shellcheck source=dapr-init.sh
  source "$REPO_ROOT/tools/track-tester/ci/dapr-init.sh"
  dapr_init_with_retry
fi

# 7. Fail loudly if the Dapr runtime that is actually running is not the pinned MAJOR.MINOR.
# Step 6 deliberately reuses an existing install (never uninstalls it), so an older runtime on a
# developer machine would otherwise pass silently and the suites would run against the wrong
# runtime. Only MAJOR.MINOR is compared, as in setup-dapr-secrets.sh.
RUNNING_RUNTIME="$(dapr --version | awk '/Runtime version/ {print $NF}')"
if [ "${RUNNING_RUNTIME%.*}" != "${DAPR_RUNTIME_VERSION%.*}" ]; then
  echo "ERROR: running Dapr runtime is $RUNNING_RUNTIME but this track pins $DAPR_RUNTIME_VERSION (the runtime has moved past the pin, or an older one is running)." >&2
  echo "Run 'dapr uninstall --all && dapr init' (this removes your Dapr containers) and re-run." >&2
  exit 1
fi

echo "Setup complete. TRACKS_SRC_DIR=$TRACKS_SRC_DIR, Aspire CLI $LAB_ASPIRE_CLI_VERSION and Dev Dashboard $DEV_DASHBOARD_VERSION in $TOOLS_BIN, expecting Dapr ${DAPR_CLI_VERSION%.*}.x"
echo "Local runs: export PATH=\"$TOOLS_BIN:\$PATH\" before running the suites."
dapr --version
