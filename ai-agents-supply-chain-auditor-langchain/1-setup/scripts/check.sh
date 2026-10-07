ENV_FILE="ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env"

# .env is provisioned by 1-setup/scripts/setup.sh from the OPENAI_API_KEY sandbox secret.
if [ ! -f "$ENV_FILE" ] || ! grep -qE "^OPENAI_API_KEY=.+" "$ENV_FILE"; then
    fail-message "The OPENAI_API_KEY wasn't provisioned in this sandbox. Restart the track, or email marc@diagrid.io if the problem persists."
fi
