SECRETS="ai-agent-tracks-instruqt/MAF/PrDigest/PrDigest.AppHost/secrets.json"
LAUNCH="ai-agent-tracks-instruqt/MAF/PrDigest/PrDigest.AppHost/Properties/launchSettings.json"

if [ ! -f "$SECRETS" ]; then
    fail-message "secrets.json not found. Copy PrDigest.AppHost/secrets.example.json to PrDigest.AppHost/secrets.json."
elif ! grep -qE '"openai-api-key"[[:space:]]*:[[:space:]]*"[^"]+"' "$SECRETS"; then
    fail-message "No OpenAI API key set in secrets.json. Paste your key as the value of \"openai-api-key\"."
elif ! grep -q "0.0.0.0:17000" "$LAUNCH"; then
    fail-message "The AppHost launchSettings.json isn't pinned to the sandbox port. Re-run the command in step 2."
else
    echo "OpenAI key configured and dashboard pinned! 👍"
fi
