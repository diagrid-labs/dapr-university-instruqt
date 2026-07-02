# Name

Making MAF agents reliable with Dapr Workflow

## Url

ai-agents-maf

## Teaser

Run a Microsoft Agent Framework (MAF) application orchestrated by Dapr Workflow, then crash it mid-run and watch it resume from durable state — without re-running the expensive LLM calls that already completed.

Languages: .NET. Duration: 30 min.

## Time limit (minutes)

30

## Description

Agents call large language models, and LLM calls are slow, costly, and non-deterministic. When a multi-agent app crashes halfway through, re-running everything from scratch wastes time and money. In this self-paced track you'll see how **Dapr Workflow** turns a fleet of **Microsoft Agent Framework (MAF)** agents into a durable, fault-tolerant application.

You'll work with **PrDigest** — a .NET Aspire app that triages open pull requests: a `PrAnalyzer` agent analyzes each PR, the workflow ranks them by risk, and a `Summarize` agent writes a headline digest.

In this self-paced track, you'll learn:
- Why durable execution matters when agents make expensive, non-idempotent LLM calls.
- How a .NET Aspire AppHost orchestrates an API service, its Dapr sidecar, and a state store with a single `aspire run`.
- How to trigger an agentic Dapr Workflow and read its ranked output.
- How a mid-run crash resumes from durable state, replaying completed agent calls from history instead of calling the LLM again.
- How to inspect workflow execution and traces.

You'll probably need around 25 minutes to complete the 4 challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
