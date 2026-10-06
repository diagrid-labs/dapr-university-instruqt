SECRETS="ai-agent-tracks-instruqt/MAF/PrDigest/PrDigest.AppHost/secrets.json"

# secrets.json is provisioned by _setup/sandbox-setup.sh from the OPENAI_API_KEY sandbox secret.
if [ ! -f "$SECRETS" ] || ! grep -qE '"openai-api-key"[[:space:]]*:[[:space:]]*"[^"]+"' "$SECRETS"; then
    fail-message "The OpenAI API key wasn't provisioned in this sandbox. Click Solve to retry, or email marc@diagrid.io if the problem persists."
fi
