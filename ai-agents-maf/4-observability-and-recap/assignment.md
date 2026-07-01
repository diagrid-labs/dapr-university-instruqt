In this final challenge you'll inspect the workflow's traces and recap what durable execution gave the MAF agents. It will take about 5 minutes.

## 1. Inspect the traces

Aspire collects distributed traces for everything it runs. Switch to the *Aspire* tab and open the **Traces** view.

1. Filter to the `pr-digest` resource.
2. Open a trace for one of your runs. You'll see spans for the workflow orchestrator and its activities, including:
   - `ListOpenPullRequestsActivity` — gathers the pull requests.
   - The `PrAnalyzer` agent calls — one per pull request (the LLM round-trips).
   - `RecordAgentCallActivity` — the checkpointed ledger write.
   - `WriteDigestActivity` — writes the ranked digest.

## 2. See the resumption in the timeline

Open the trace for the `run-crash` instance from the previous challenge.

- Spans from the **first run** stop at the crash point (the 3rd agent call).
- Spans from the **resumed run** continue with the remaining pull requests and the completion steps.
- The already-analyzed pull requests have **no new agent-call spans** in the resumed run — their results came from durable history, not a fresh LLM call.

> [!NOTE]
> Compare the timestamps either side of the gap: that's the crash-and-restart cost, sitting inside one logical workflow run.

## 3. Recap

You saw how Dapr Workflow makes a Microsoft Agent Framework application reliable:

- Every agent call is a **checkpointed activity**. Its result is written to durable Valkey state the moment it completes.
- A crash mid-run **rehydrates from that state** and replays completed calls from history — so expensive, non-deterministic LLM calls are never repeated.
- A single `aspire run` orchestrates the API service, the Dapr sidecar, and the state store, with a dashboard for resources and traces.

That combination turns a fleet of agents into a fault-tolerant application you can crash without losing — or paying for — completed work twice.

## Feedback and further learning

Congratulations! 🎉 You've completed the *Making MAF agents reliable with Dapr Workflow* learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving it.

We have more ways for you to learn and share knowledge:

**Try another university track**
- [Build Dapr workflows in .NET with Aspire](https://www.diagrid.io/university/dapr-workflow-aspire)
- [Dapr Workflow: Use durable execution to build reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Read more**
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).
- Learn more about [Diagrid Catalyst](https://www.diagrid.io/catalyst), the enterprise platform for reliable and secure AI agents and workflows.

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#dotnet*, and *#agents* channels.
