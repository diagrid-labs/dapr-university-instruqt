In this challenge you'll re-enable the `before_llm_call` hook and watch the same question from challenge 2 get a much better answer.

## 1. Inspect the hook

Open `dapr-agents/examples/11-expert-agent-tavily/hooks.py` in the **Editor** window. It's short:

```python,nocopy
@lru_cache(maxsize=1)
def _client() -> TavilyClient:
    return TavilyClient(api_key=os.environ["TAVILY_API_KEY"])


def enrich_with_tavily(ctx: HookContext) -> HookDecision:
    messages = ctx.payload.get("messages", [])
    if not messages or messages[-1].get("role") != "user":
        return Proceed()

    question = messages[-1]["content"]
    results = _client().search(query=question, max_results=3)
    snippets = "\n".join(
        f"- {r['title']}: {r['content']}" for r in results.get("results", [])
    )
    if not snippets:
        return Proceed()

    enriched_messages = [
        *messages[:-1],
        {"role": "system", "content": f"Fresh web context (Tavily):\n{snippets}"},
        messages[-1],
    ]
    return Modify(payload={**ctx.payload, "messages": enriched_messages})
```

A `before_llm_call` hook receives a `HookContext` whose `payload` is the LLM call's kwargs — most usefully, `messages`. The hook pulls out the latest user question, web-searches it with Tavily, and returns `Modify(payload=...)` to splice the results into the prompt as a system message right before the user's question.

The returned `Modify(payload=...)` replaces the LLM kwargs before `self.llm.generate(...)` actually fires.

## 2. Look at where the hook is registered

Open `agent.py`. The setup script already uncommented this line:

```python,nocopy
hooks=Hooks(before_llm_call=[enrich_with_tavily]),
```

That's the entire wiring. `Hooks` is a dataclass with four slots (`before_tool_call`, `after_tool_call`, `before_llm_call`, `after_llm_call`) — pass your callable to whichever slot you need.

## 3. Why a hook, not a tool?

Three reasons.

1. **Always-on enrichment.** A tool depends on the model *choosing* to call it. For questions the model thinks it knows, it won't. A hook fires for every LLM call regardless.
2. **Decoupling.** The hook lives with the agent. The same `DurableAgent` exposed via FastAPI, pub/sub, or any other surface gets the same enrichment for free.
3. **Activity durability.** The hook runs inside the `call_llm` activity. Dapr Workflow records the activity's output, so on replay the recorded assistant message is reused — Tavily fires **once per turn**, not on every replay. This is the magic that makes "non-deterministic enrichment inside a durable workflow" actually work.

## 4. Run it

Same command as challenge 2:

```bash,run
cd dapr-agents/examples/11-expert-agent-tavily
uv run dapr run --app-id expert-agent --resources-path ./resources -- chainlit run app.py -w
```

In the browser, ask the same question as in challenge 2:

```text,nocopy
What's the latest Dapr release version, and what changed in it?
```

This time you should see an answer that references **current** version numbers and release notes. Watch the terminal too — you'll see a log line each turn:

```text,nocopy
[hook] Tavily search: 'What's the latest Dapr release version, and what changed in it?'
```

That's the hook firing.

## 5. Try a few more questions

Anything that needs fresh data is a good demo:

- *"Summarize the biggest open-source security advisory this week."*
- *"Who won the most recent F1 race?"*
- *"What's the current state of the EU AI Act?"*

## 6. Inspect the trace (optional)

Dapr ships Zipkin out of the box. Open `http://localhost:9411` and find your agent's trace — drill into the `call_llm` activity span and look at the input. You'll see the injected `Fresh web context (Tavily):` system message right before the user message, exactly the way the hook spliced it in.

## 7. Stop the agent

`Ctrl+C` in the Terminal.

## Congratulations 🎉

You've built an expert agent that uses one of the most powerful patterns the new hook system enables: silent prompt enrichment via a `before_llm_call` hook. With ~30 lines of hook code you've given the agent abilities that would otherwise require a tool the model has to remember to call.

Next steps you can explore on your own:

- Cache Tavily results per query inside the hook with a small `dict` keyed on the question.
- Add an `after_llm_call` hook that logs the final answer and the sources it cited.
- Swap `OpenAIChatClient` for another provider — the hook keeps working unchanged.
