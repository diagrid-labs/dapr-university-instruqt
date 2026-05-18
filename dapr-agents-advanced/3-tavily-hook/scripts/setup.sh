cd dapr-agents/examples/11-expert-agent-tavily

# Re-enable the hook by stripping the leading "# " the challenge 2 setup added.
sed -i 's|^\(\s*\)# hooks=Hooks(before_llm_call=\[enrich_with_tavily\]),.*|\1hooks=Hooks(before_llm_call=[enrich_with_tavily]),|' agent.py
