ENV_FILE="dapr-agents/examples/11-expert-agent-tavily/.env"

# .env is provisioned by 1-what-is-advanced/scripts/setup.sh from the OPENAI_API_KEY and TAVILY_API_KEY sandbox secrets.
for KEY in OPENAI_API_KEY TAVILY_API_KEY; do
    if [ ! -f "$ENV_FILE" ] || ! grep -qE "^${KEY}=.+" "$ENV_FILE"; then
        fail-message "The ${KEY} wasn't provisioned in this sandbox. Restart the track, or email marc@diagrid.io if the problem persists."
    fi
done
