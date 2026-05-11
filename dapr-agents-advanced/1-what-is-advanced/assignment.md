Welcome to **Dapr Agents Advanced**. This track is a follow-up to the [Dapr Agents](../dapr-agents) fundamentals track. You'll build an end-user-facing **expert agent**: a `DurableAgent` behind a [Chainlit](https://chainlit.io/) chat UI that silently fetches fresh web context for every question via a `before_llm_call` hook backed by [Tavily](https://tavily.com).

## What you'll build

By the end of the track, you'll have an agent that can confidently answer questions about *current* events — things like the latest Dapr release, this week's news, or any topic that postdates the LLM's training cutoff — without you having to add a `web_search` tool the model has to remember to call.

The magic is in the **hook system** introduced in `dapr-agents` PRs [#571](https://github.com/dapr/dapr-agents/pull/571) (tool hooks, HITL) and [#595](https://github.com/dapr/dapr-agents/pull/595) (LLM hooks). A hook is a callback that fires around every tool dispatch or LLM call. With one short hook function you can:

- Log every call
- Replace prompt content
- Cache responses
- Block dangerous calls
- Pause for human approval

For this track we'll focus on the `before_llm_call` slot — the one that lets you inject fresh context into every prompt automatically.

## What's in this challenge

This first challenge is sandbox setup only. The environment has just:

1. Cloned `https://github.com/dapr/dapr-agents`
2. Installed the Dapr CLI and run `dapr init`
3. Installed the `uv` Python package manager

You'll work inside `~/dapr-agents/examples/10-expert-agent-tavily/` in the upcoming challenges. Take a peek at the [README](https://github.com/dapr/dapr-agents/tree/main/examples/10-expert-agent-tavily) if you want a sneak preview.

### Why a hook and not a tool?

The model decides when to call a tool. For a question like *"What's the latest Dapr release?"* the model often **thinks it knows** and answers from stale training data — wrong, but confident.

A `before_llm_call` hook fires for **every** LLM call regardless of what the model would have chosen. The user's question gets enriched whether the model thinks it needs help or not. We'll see exactly this contrast in challenges 2 and 3.

When you're ready, click *Check* to move to challenge 2.
