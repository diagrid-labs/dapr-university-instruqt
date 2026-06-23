Welcome to the **Dapr Agents - Using Hooks** track! This track is a follow-up to the Dapr Agents 101 track. In this track you'll build an end-user-facing **expert agent**: a `DurableAgent` behind a [Chainlit](https://chainlit.io/) chat UI that silently fetches fresh web context for every question via a `before_llm_call` hook backed by [Tavily](https://tavily.com).

## What you'll build

By the end of the track, you'll have an agent that can confidently answer questions about *current* events — things like the latest Dapr release, this week's news, or any topic that postdates the LLM's training cutoff — without you having to add a `web_search` tool the model has to remember to call.

The magic is in `dapr-agents` **hook system**. A hook is a callback that fires around every tool dispatch or LLM call. With one short hook function you can:

- Log every call
- Replace prompt content
- Cache responses
- Block dangerous calls
- Pause for human approval

For this track we'll focus on the `before_llm_call` slot — the one that lets you inject fresh context into every prompt automatically.

### Why a hook and not a tool?

The model decides when to call a tool. For a question like *"What's the latest Dapr release?"* the model often **thinks it knows** and answers from stale training data — wrong, but confident.

A `before_llm_call` hook fires for **every** LLM call regardless of what the model would have chosen. The user's question gets enriched whether the model thinks it needs help or not. We'll see exactly this contrast in challenges 2 and 3.

## What's in this challenge

This first challenge is sandbox verification only. The sandbox has the follow already configured:

1. Cloned `https://github.com/dapr/dapr-agents`
2. Installed the Dapr CLI and run `dapr init`
3. Installed the `uv` Python package manager

### Verification

1. Verify that dapr is initialized:

```shell,copy,run
dapr -v
```
The ouput should show the version of both the Dapr CLI and the runtime. Only if the **Runtime version** is empty, initialize Dapr by running `dapr init`. This will install several containers that Dapr requires, including a Redis container that is used for the workflow state.

2. Verify that uv is installed:

```shell,copy,run
uv --version
```

The output should show the version of uv. If the command is not recognized, install it via `wget -qO- https://astral.sh/uv/install.sh | sh`.

When you're ready, click *Next* to move to challenge 2.
