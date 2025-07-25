# Copy .env file with OPENAI_API_KEY to the other quickstart folder that require it
cp dapr-agents/quickstarts/02_llm_call_open_ai/.env dapr-agents/quickstarts/03-agent-tool-call/.env
cp dapr-agents/quickstarts/02_llm_call_open_ai/.env dapr-agents/quickstarts/07-agent-mcp-client-stdio/.env
cp dapr-agents/quickstarts/02_llm_call_open_ai/.env dapr-agents/quickstarts/01-hello-world/.env
cp dapr-agents/quickstarts/02_llm_call_open_ai/.env dapr-agents/quickstarts/04-agentic-workflow/.env
cp dapr-agents/quickstarts/02_llm_call_open_ai/.env dapr-agents/quickstarts/05-multi-agent-workflows/.env

# Extract the OPENAI_API_KEY from the .env file and insert it in the openai.yaml file.
export $(grep -v '^#' dapr-agents/quickstarts/02_llm_call_open_ai/.env | xargs)
sed -i "s|<OPENAI_API_KEY>|$OPENAI_API_KEY|g" dapr-agents/quickstarts/02_llm_call_dapr/components/openai.yaml
