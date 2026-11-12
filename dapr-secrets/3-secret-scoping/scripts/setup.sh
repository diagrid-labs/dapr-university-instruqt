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

# Build both apps in all three languages so switching language is not slow. The folder names
# follow each language: PascalCase for .NET, kebab-case for Python and Java.
for app in AppA AppB; do
    (cd "$TRACKS_SRC_DIR/secrets/dotnet/Demo2-Scoping/$app" && dotnet build)
done
for app in app-a app-b; do
    (cd "$TRACKS_SRC_DIR/secrets/python/demo2-scoping/$app" && uv sync)
    (cd "$TRACKS_SRC_DIR/secrets/java/demo2-scoping/$app" && mvn -q -DskipTests package)
done
