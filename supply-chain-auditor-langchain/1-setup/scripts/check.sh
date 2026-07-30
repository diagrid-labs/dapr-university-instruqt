ENV_FILE="ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env"

if [ ! -f "$ENV_FILE" ]; then
    fail-message "No .env file found at $ENV_FILE. Make sure the sandbox finished setting up."
elif grep -qE '^ANTHROPIC_API_KEY=your_key_here[[:space:]]*$' "$ENV_FILE"; then
    fail-message "ANTHROPIC_API_KEY is still the placeholder. Replace 'your_key_here' with your real Anthropic API key in the .env file, then click Check again."
elif ! grep -qE '^ANTHROPIC_API_KEY=.+' "$ENV_FILE"; then
    fail-message "ANTHROPIC_API_KEY is empty in .env. Paste your key after the '=' sign, then click Check again."
fi
