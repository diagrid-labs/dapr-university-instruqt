cd dapr-agents/examples/10-expert-agent-tavily

# Comment out the hooks= line so we run the baseline (no enrichment) in this challenge.
sed -i 's|^\(\s*\)hooks=Hooks(before_llm_call=\[enrich_with_tavily\]),|\1# hooks=Hooks(before_llm_call=[enrich_with_tavily]),  # disabled for challenge 2|' agent.py

# Seed an empty .env the learner fills in.
cat > .env << 'EOF'
OPENAI_API_KEY=your_openai_api_key_here
TAVILY_API_KEY=your_tavily_api_key_here
EOF

uv sync --active
