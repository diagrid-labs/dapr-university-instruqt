# Name

Dapr Agents Advanced - Build a Chainlit-powered expert agent with hooks

## Url

dapr-agents-advanced

## Teaser

You'll build an end-user-facing expert agent that uses a Chainlit chat UI and a `before_llm_call` hook to silently inject fresh Tavily web-search results into every prompt — "RAG via hook." Picks up where the Dapr Agents track left off.

## Time limit (minutes)

45

## Description

In this self-paced track you'll learn:

- How to give a `DurableAgent` a Chainlit chat front-end.
- What hooks are and how the four hook slots (`before_tool_call`, `after_tool_call`, `before_llm_call`, `after_llm_call`) work.
- How to use a `before_llm_call` hook to enrich every LLM prompt with fresh web context from Tavily, without the model needing to choose a `web_search` tool.
- Why hook-based enrichment beats UI-layer enrichment for decoupling, tool-loop safety, and durability.

This is the follow-up to the **Dapr Agents** fundamentals track. We assume you're already comfortable with `DurableAgent`, tool calls, and basic Dapr Workflow concepts.

You'll need an OpenAI API key (https://platform.openai.com/signup) and a Tavily API key (https://tavily.com — free tier covers 1000 searches/month) to complete this track.

This track has 3 challenges. You'll probably need about 30 minutes to complete them.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges via the *Progress* button.

### Time out idle users (minutes)

10

### Extra time (minutes)

10

### Max restarts

5
