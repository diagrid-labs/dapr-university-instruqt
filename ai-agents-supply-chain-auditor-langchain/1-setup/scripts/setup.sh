git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git

# Provision the OpenAI API key from the OPENAI_API_KEY Instruqt sandbox secret into the
# .env read by load_dotenv() in app.py, so the learner doesn't have to supply their own key.
cat > ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env <<EOF
OPENAI_API_KEY=${OPENAI_API_KEY}
GITHUB_TOKEN=
PR_REPO=dapr/dapr-agents
PR_NUMBER=635
DEP_ECOSYSTEM=pip
LLM_MODEL=gpt-4.1-mini
LOG_LEVEL=INFO
EOF

# Install the Dapr Dev Dashboard into a directory that's on every shell's PATH
curl -sSL https://raw.githubusercontent.com/diagridio/dev-dashboard/main/scripts/install.sh | BIN_DIR=/usr/local/bin sh
