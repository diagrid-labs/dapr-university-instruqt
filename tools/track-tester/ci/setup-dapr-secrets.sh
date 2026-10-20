#!/usr/bin/env bash
# Reproduce the dapr-secrets sandbox environment in CI by reusing the real _setup script.
# Instruqt-only bits (agent variable set, docker login) are adapted/omitted here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SETUP_DIR="$REPO_ROOT/dapr-secrets/_setup"
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-$HOME/ai-agent-tracks-instruqt}"

# 1. Parse the pinned Dapr versions (single source of truth) and export them for the suites.
# awk is used (not grep -oP) so this runs on both macOS/BSD and GNU/Linux. The lines look like
# `agent variable set DAPR_CLI_VERSION 1.18.2`, so the version is the last field ($NF).
DAPR_CLI_VERSION="$(awk '/DAPR_CLI_VERSION/ {print $NF}' "$SETUP_DIR/sandbox-setup.sh")"
DAPR_RUNTIME_VERSION="$(awk '/DAPR_RUNTIME_VERSION/ {print $NF}' "$SETUP_DIR/sandbox-setup.sh")"
echo "DAPR_CLI_VERSION=$DAPR_CLI_VERSION"     >> "${GITHUB_ENV:-/dev/stdout}"
echo "DAPR_RUNTIME_VERSION=$DAPR_RUNTIME_VERSION" >> "${GITHUB_ENV:-/dev/stdout}"
echo "TRACKS_SRC_DIR=$TRACKS_SRC_DIR" >> "${GITHUB_ENV:-/dev/stdout}"

# 2. Clone the demo repo (source of truth for the demo apps and resources).
if [ ! -d "$TRACKS_SRC_DIR/.git" ]; then
  git clone --depth 1 https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git "$TRACKS_SRC_DIR"
fi

# 3. Install uv (used by the Python demos and to run robot).
# curl (not wget) so this runs on macOS too - macOS ships curl but not wget.
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
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
# start + seed Vault. Duplicated from dapr-secrets/_setup/sandbox-setup.sh, which cannot be run
# in CI (Instruqt-only commands); keep the two in sync.
cp "$TRACKS_SRC_DIR/secrets/secrets.example.json" "$TRACKS_SRC_DIR/secrets/secrets.json"
docker rm -f vault >/dev/null 2>&1 || true
docker run -d --name vault -p 8200:8200 --cap-add=IPC_LOCK \
  -e VAULT_DEV_ROOT_TOKEN_ID=root -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  hashicorp/vault:1.20 >/dev/null
for _ in $(seq 1 30); do
  docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault vault status >/dev/null 2>&1 && break
  sleep 1
done
python3 -c 'import json, sys; [print(k, v) for k, v in json.load(open(sys.argv[1])).items()]' \
  "$TRACKS_SRC_DIR/secrets/secrets.json" | tr -d '\r' | while read -r name value; do
  docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=root vault \
    vault kv put "secret/dapr/$name" "$name=$value" >/dev/null </dev/null
done

# 6. Fail loudly if the Dapr runtime that is actually running is not the pinned MAJOR.MINOR.
# Step 4 deliberately reuses an existing install (never uninstalls it), so an older runtime on a
# developer machine would otherwise pass silently and challenge 3's 403/500 assertions would run
# against the wrong runtime. Only MAJOR.MINOR is compared, as in setup-dapr-101.sh.
RUNNING_RUNTIME="$(dapr --version | awk '/Runtime version/ {print $NF}')"
if [ "${RUNNING_RUNTIME%.*}" != "${DAPR_RUNTIME_VERSION%.*}" ]; then
  echo "ERROR: running Dapr runtime is $RUNNING_RUNTIME but this track pins $DAPR_RUNTIME_VERSION." >&2
  echo "The secret-denial wording (403 ERR_PERMISSION_DENIED / 500 ERR_SECRET_GET) is version-sensitive, so the suites would assert against the wrong runtime. Run 'dapr uninstall --all && dapr init' (this removes your Dapr containers) and re-run." >&2
  exit 1
fi

echo "Setup complete. TRACKS_SRC_DIR=$TRACKS_SRC_DIR, expecting Dapr ${DAPR_CLI_VERSION%.*}.x"
dapr --version
