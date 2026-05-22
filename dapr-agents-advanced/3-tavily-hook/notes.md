In this challenge, the setup script re-enables the `hooks=Hooks(before_llm_call=[enrich_with_tavily])` line in `agent.py` via sed, so the agent runs **with** the Tavily hook.

The learner re-runs the same `dapr run … chainlit run` command from challenge 2 and asks the same "what's the latest …" question. The answer should now reference current information.

Key pedagogical points to surface (already in `assignment.md`):

1. The hook fires for every LLM call regardless of model intent.
2. It runs inside the `call_llm` activity, so the Tavily network call is replay-safe.
3. It's decoupled from the UI — the same agent would work behind FastAPI, pub/sub, or any other entry point.

The `notes.md` for challenge 1 already explains the rationale; this `notes.md` is brief because the lesson is mostly in the assignment.
