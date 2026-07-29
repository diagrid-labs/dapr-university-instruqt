# Name

Audit dependency bumps for supply-chain attacks with Dapr Workflow

## Url

supply-chain-auditor

## Teaser

Run an AI agent that audits a real Dependabot PR for a supply-chain attack — where a dependency's changelog says "docs only" but the code slips in something malicious. It runs as a durable Dapr Workflow, so when you crash it mid-audit it resumes from durable state without repeating the expensive Claude analysis.

Languages: Python. Duration: 30 min. Requires an Anthropic API key.

## Time limit (minutes)

30

## Description

Dependabot opens a pull request; its changelog says "documentation only". But does the actual source diff match that claim? The classic supply-chain attack hides malicious code — an install hook, a credential grab, an obfuscated payload — inside an update whose notes read as innocent. In this self-paced track you'll run the **Supply Chain Auditor**, an AI agent that checks a dependency bump's upstream release notes against its real source changes, and see how **Dapr Workflow** makes that audit durable.

You'll work with a staged [LangGraph](https://www.langchain.com/langgraph) pipeline — `gather_evidence → analyze → render_report` — where only the `analyze` node calls Claude, and every node runs as a checkpointed Dapr Workflow activity.

In this self-paced track, you'll learn:
- How the auditor combines deterministic red-flag heuristics with an LLM judgement, and why the heuristics set a floor the model can only raise.
- Why durable execution matters when one node in a pipeline makes an expensive, non-idempotent LLM call.
- How each pipeline node becomes a Dapr Workflow activity checkpointed to a Redis state store.
- How a real mid-run crash resumes from durable state — replaying the completed `gather_evidence` and `analyze` steps from history instead of re-fetching from GitHub or calling Claude again.

You'll probably need around 22 minutes to complete the 3 challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
