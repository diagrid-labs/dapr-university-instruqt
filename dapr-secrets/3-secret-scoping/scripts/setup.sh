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

# Build both apps in all three languages so switching language is not slow.
for app in AppA AppB; do
    (cd "$TRACKS_SRC_DIR/secrets/dotnet/Demo2-Scoping/$app" && dotnet build)
    (cd "$TRACKS_SRC_DIR/secrets/python/Demo2-Scoping/$app" && uv sync)
    (cd "$TRACKS_SRC_DIR/secrets/java/Demo2-Scoping/$app" && mvn -q -DskipTests package)
done
