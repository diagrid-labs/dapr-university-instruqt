# Audit dependency bumps for supply-chain attacks with Dapr Workflow

A dependency update's changelog is attacker-controllable text. When it says "documentation only" but the source diff adds an install hook that curls a script and pipes it to a shell, you have a supply-chain attack. In this hands-on track you'll run an AI agent that catches exactly that — and see how Dapr Workflow makes the audit durable enough to survive a crash.

## What you'll build

You'll run the **Supply Chain Auditor** — a staged LangGraph pipeline that audits a real Dependabot pull request. It resolves the bumped package to its upstream repo, fetches the release notes and the actual source diff, runs deterministic red-flag heuristics, and asks Claude to judge whether the narrative matches the code. Only the `analyze` node calls the LLM; every node runs as a checkpointed Dapr Workflow activity. Then you'll crash the process mid-audit and watch it resume without repeating the Claude call.

## What you'll learn

- How a security-focused agent grounds an LLM in untrusted, nonce-tagged evidence and enforces a deterministic heuristic floor the model can only raise.
- Why durable execution is essential when a pipeline node makes an expensive, non-idempotent LLM call.
- How Dapr Workflow checkpoints each pipeline node so completed work replays from history, not recomputation.
- How a real process crash resumes from durable Redis state without re-fetching from GitHub or re-invoking Claude.

## Supported language

Python

## Prerequisites

Familiarity with Python and basic command-line tooling is recommended. The sandbox comes preconfigured with Docker, Python, `uv`, and Dapr. You'll need your own Anthropic API key (Claude) to run the `analyze` step.
