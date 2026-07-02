# Making MAF agents reliable with Dapr Workflow

Agents are only as reliable as the runtime underneath them. LLM calls are slow, cost money, and never return the same thing twice — so when a multi-agent application crashes halfway through, re-running it from the start is exactly what you don't want. In this hands-on track you'll see how Dapr Workflow gives Microsoft Agent Framework (MAF) agents durable, crash-proof execution.

## What you'll build

You'll run **PrDigest** — a .NET Aspire application that triages open pull requests for an open-source maintainer. A `PrAnalyzer` MAF agent analyzes each pull request, a Dapr Workflow fans the work out and ranks the results by risk, and a `Summarize` MAF agent writes a headline digest. Then you'll deliberately crash it mid-run and watch it pick up exactly where it left off.

## What you'll learn

- Why durable execution is essential when agents make expensive, non-idempotent LLM calls.
- How Dapr Workflow checkpoints each agent call so completed work is replayed from history, not recomputed.
- How .NET Aspire orchestrates the API service, the Dapr sidecar, and a Valkey state store from a single AppHost.
- How to trigger an agentic workflow over HTTP and read its ranked digest output.
- How a real process crash resumes from durable state without repeating completed agent (LLM) calls.
- How to inspect workflow instances and traces while the app runs.

## Supported language

.NET

## Prerequisites

Familiarity with C# and basic .NET tooling is recommended. The sandbox comes preconfigured with Docker, the .NET 10 SDK, the Aspire CLI, and Dapr. You'll need your own OpenAI API key (with access to `gpt-4o-mini`) to run the agents.
