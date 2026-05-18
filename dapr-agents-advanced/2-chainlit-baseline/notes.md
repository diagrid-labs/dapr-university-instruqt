In this challenge, the setup script:

- `cd`s into `~/dapr-agents/examples/11-expert-agent-tavily/`
- Comments out the `hooks=Hooks(before_llm_call=[enrich_with_tavily])` line in `agent.py` so the agent runs **without** any hook
- Runs `uv sync` to install dependencies
- Creates an empty `.env` file the learner fills in

The challenge demonstrates the **baseline** behavior — a `DurableAgent` answering directly from training data. Learners should ask a "what's the latest …" type question and see that the model either hedges or gives a stale answer. That sets up the *aha* moment in challenge 3.

The `cleanup.sh` doesn't propagate any secrets — challenge 3 runs in the same directory, so the `.env` file persists.
