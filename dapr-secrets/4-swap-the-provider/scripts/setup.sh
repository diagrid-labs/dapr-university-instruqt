set -e
export PATH="$HOME/.local/bin:$PATH"

# Self-sufficient: this challenge may be started directly from Instruqt's Progress button,
# so it does not rely on sandbox-setup.sh (or an earlier challenge) having run.
TRACKS_SRC_DIR="$HOME/ai-agent-tracks-instruqt"
if [ ! -d "$TRACKS_SRC_DIR/secrets" ]; then
    git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git "$TRACKS_SRC_DIR"
fi
if [ ! -f "$TRACKS_SRC_DIR/secrets/secrets.json" ]; then
    cp "$TRACKS_SRC_DIR/secrets/secrets.example.json" "$TRACKS_SRC_DIR/secrets/secrets.json"
fi

# Build the demo app in all three languages so switching language is not slow. The swap itself
# runs this same build: Demo3-SwapProvider only holds a dapr.yaml and the Vault component.
(cd "$TRACKS_SRC_DIR/secrets/dotnet/Demo1-ReadSecret" && dotnet build)
(cd "$TRACKS_SRC_DIR/secrets/python/Demo1-ReadSecret" && uv sync)
(cd "$TRACKS_SRC_DIR/secrets/java/Demo1-ReadSecret" && mvn -q -DskipTests package)

# Vault is started and seeded by sandbox-setup.sh. Fail here, with a clear message, instead of
# letting the learner meet an opaque sidecar error later.
if ! curl -s -f -m 5 http://localhost:8200/v1/sys/health >/dev/null; then
    echo "ERROR: Vault does not answer on port 8200. Is the 'vault' container running? Check 'docker ps' and 'docker logs vault'." >&2
    exit 1
fi
