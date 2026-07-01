SECRETS="ai-agent-tracks-instruqt/MAF/PrDigest/PrDigest.AppHost/secrets.json"

if [ ! -f "$SECRETS" ]; then
    fail-message "secrets.json not found. Copy PrDigest.AppHost/secrets.example.json to PrDigest.AppHost/secrets.json."
elif ! grep -qE '"openai-api-key"[[:space:]]*:[[:space:]]*"[^"]+"' "$SECRETS"; then
    fail-message "No OpenAI API key set in secrets.json. Paste your key as the value of \"openai-api-key\"."
fi