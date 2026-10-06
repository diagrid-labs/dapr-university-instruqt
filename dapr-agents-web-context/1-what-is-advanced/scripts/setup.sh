wget -qO- https://astral.sh/uv/install.sh | sh

# Provision the OpenAI and Tavily API keys from the OPENAI_API_KEY and TAVILY_API_KEY
# Instruqt sandbox secrets into the example's .env (read by load_dotenv() in app.py),
# so the learner doesn't have to supply their own keys.
EX="$PWD/dapr-agents/examples/11-expert-agent-tavily"
cat > "$EX/.env" <<EOF
OPENAI_API_KEY=${OPENAI_API_KEY}
TAVILY_API_KEY=${TAVILY_API_KEY}
EOF

# Use gpt-4.1-mini instead of the example's default model.
sed -i 's/OpenAIChatClient(model="gpt-4o-mini")/OpenAIChatClient(model="gpt-4.1-mini")/' "$EX/agent.py"