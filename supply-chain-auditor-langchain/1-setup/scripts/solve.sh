ENV_FILE="ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env"
sed -i 's/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=sk-ant-dummy-key-for-solve/' "$ENV_FILE"
