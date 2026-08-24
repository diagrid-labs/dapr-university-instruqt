BASHRC="${BASHRC:-$HOME/.bashrc}"

# Instruqt runs this script non-interactively, and ~/.bashrc early-returns for
# non-interactive shells, so sourcing it would not expose the key. Read the file
# instead and take the LAST export — that is the value an interactive tab ends up with.
KEY=$(grep -E '^[[:space:]]*export[[:space:]]+OPENAI_API_KEY=' "$BASHRC" 2>/dev/null \
    | tail -1 \
    | sed -E "s/^[^=]*=//; s/[[:space:]]*\$//; s/^[\"']//; s/[\"']\$//")

if [ -z "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
    fail-message "Dapr containers are not running. Run 'dapr init' in the Terminal, then click Check again."
elif [ -z "$KEY" ]; then
    fail-message "No 'export OPENAI_API_KEY=...' line found in ~/.bashrc. Copy the command from step 2, replace your_key_here with your real key, and run it in the Terminal."
elif [ "$KEY" = "your_key_here" ]; then
    fail-message "OPENAI_API_KEY is still the placeholder 'your_key_here'. Run the command again with your real key — the last export in ~/.bashrc is the one that counts."
else
    echo "Sandbox ready and API key set! 👍"
fi
