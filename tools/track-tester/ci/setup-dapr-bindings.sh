#!/usr/bin/env bash
# Reproduce the dapr-bindings sandbox environment in CI by reusing the real _setup scripts.
# Instruqt-only bits (agent variable set, docker login) are adapted/omitted here.
set -euo pipefail

AI_AGENT_TRACKS_DIR="${AI_AGENT_TRACKS_DIR:-$HOME/ai-agent-tracks-instruqt}"
echo "AI_AGENT_TRACKS_DIR=$AI_AGENT_TRACKS_DIR" >> "${GITHUB_ENV:-/dev/stdout}"

# 1. Clone the sample-code repo (drift source of truth).
if [ ! -d "$AI_AGENT_TRACKS_DIR/.git" ]; then
  git clone --depth 1 https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git "$AI_AGENT_TRACKS_DIR"
fi

# 2. Install uv (used by the Python app and to run robot).
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# 3. Install the Dapr CLI and initialize Dapr exactly as assignment.md tells the learner to.
if ! command -v dapr >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash
fi
dapr uninstall --all >/dev/null || true
dapr init

# 4. Start the local Postgres container, same as _setup/sandbox-setup.sh.
docker rm -f dapr_postgres >/dev/null 2>&1 || true
docker run -d --name dapr_postgres \
  -e POSTGRES_PASSWORD=dapr123 \
  -e POSTGRES_DB=venuedb \
  -p 5432:5432 \
  -v "$AI_AGENT_TRACKS_DIR/bindings/venue-bookings/python/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  postgres:16

# Wait for Postgres to actually accept connections before handing control back.
for i in $(seq 1 30); do
  if docker exec dapr_postgres pg_isready -U postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# 5. Pre-install the Python dependencies (dotnet and java restore/build on first run, inside the suites).
(cd "$AI_AGENT_TRACKS_DIR/bindings/venue-bookings/python" && uv sync)

echo "Setup complete. AI_AGENT_TRACKS_DIR=$AI_AGENT_TRACKS_DIR"
dapr --version
