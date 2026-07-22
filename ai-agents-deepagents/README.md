# Name

Make DeepAgents reliable with Dapr Workflow

## Url

ai-agents-deepagents

## Teaser

Run a DeepAgents application that investigates a real GitHub issue, then crash it mid-run and watch Dapr Workflow resume the investigation from durable state — without re-running the expensive LLM calls that already completed.

Languages: Python. Duration: 30 min. Requires an OpenAI API key.

## Time limit (minutes)

30

## Description

Agents call large language models, and LLM calls are slow, costly, and non-deterministic. A real issue investigation isn't one LLM call — it's dozens of tool calls and reasoning steps, and by default all of that lives in memory. Kill the process halfway through and you lose everything. In this self-paced track you'll see how **Dapr Workflow** turns a [DeepAgents](https://docs.langchain.com/oss/python/deepagents) agent into a durable, fault-tolerant application.

You'll work with a Python CLI tool that investigates a real Dapr bug — [dapr/dapr#7326](https://github.com/dapr/dapr/issues/7326) — using a DeepAgent that plans its own steps, calls tools against a local GitHub data snapshot, and writes a Markdown investigation report.

In this self-paced track, you'll learn:
- What DeepAgents is, and why durable execution matters when agents make expensive, non-idempotent LLM calls.
- How to run a DeepAgent that plans, calls tools, and writes an investigation report on its own.
- How to wrap the agent in a Dapr Workflow so every tool call becomes a checkpointed workflow activity backed by a Redis state store.
- How a mid-run crash resumes from durable state, replaying completed activities from history instead of calling the LLM again.

You'll probably need around 25 minutes to complete the 4 challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
