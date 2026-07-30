git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git

cat > ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env << 'EOF'
ANTHROPIC_API_KEY=your_key_here
GITHUB_TOKEN=
PR_REPO=dapr/dapr-agents
PR_NUMBER=635
DEP_ECOSYSTEM=pip
LLM_MODEL=claude-sonnet-4-6
LOG_LEVEL=INFO
EOF
