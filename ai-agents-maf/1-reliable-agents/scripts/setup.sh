git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git

# Provision the OpenAI API key from the OPENAI_API_KEY Instruqt sandbox secret into the
# git-ignored secrets.json read by the Dapr local file secret store, so the learner
# doesn't have to supply (or see) a key.
if [ -n "${OPENAI_API_KEY}" ]; then
    jq -n --arg k "${OPENAI_API_KEY}" '{"openai-api-key": $k}' \
        > ai-agent-tracks-instruqt/MAF/PrDigest/PrDigest.AppHost/secrets.json
fi

# Install the Dapr Dev Dashboard
curl -sSL https://raw.githubusercontent.com/diagridio/dev-dashboard/main/scripts/install.sh | BIN_DIR=/usr/local/bin sh