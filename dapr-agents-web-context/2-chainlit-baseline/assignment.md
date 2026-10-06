In this challenge you'll run the expert agent **without** the Tavily hook — the baseline behavior. The setup script has already commented out the `hooks=...` line in `agent.py`, so the agent talks to the LLM directly with no prompt enrichment. This hands-on challenge takes about 10 minutes to complete.

## 1. Inspect the agent

Open `dapr-agents/examples/11-expert-agent-tavily/agent.py` in the **Editor** window. You'll see a `DurableAgent` configured with:

- An OpenAI chat client using the `gpt-4.1-mini` model
- Conversation memory backed by Redis
- A workflow state store (actor-enabled, as required by Dapr Workflow)
- An agent registry

The last argument — the one the setup script commented out — is the hooks registration:

```python,nocopy
# hooks=Hooks(before_llm_call=[enrich_with_tavily]),  # disabled for challenge 2
```

Leave it as-is. The setup script for challenge 3 re-enables it.

## 2. Run the agent

Use the **Terminal** window to start Dapr and Chainlit in a single command:

```bash,copy,run
uv run dapr run --app-id expert-agent --resources-path ./resources -- chainlit run app.py -w --host 0.0.0.0 --port 8000
```

Open the Chainlit chat interface via the **Chainlit** tab.

## 3. Ask a "current events" question

In the Chainlit chat, type something the model can't possibly know from its training cutoff:

```text,copy
What's the latest Dapr release version, and what changed in it?
```

After a few seconds you'll get a response. You'll get one of two answers, both wrong:

- **Hedge:** "I don't have information past my training cutoff…"
- **Confident-but-stale:** an old release version stated authoritatively.

This is the problem we're solving in challenge 3 — give the model fresh context **automatically**, without it needing to choose to call a `web_search` tool.

## 4. Stop the agent

In the Terminal, press `Ctrl+C` to stop Dapr.

When you're ready, click *Next* to move to challenge 3.
