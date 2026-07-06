In this final challenge you'll prove the durability of the application. You'll interrupt the workflow with a real process crash, restart it, and prove that the `PrAnalyzer` agent calls that already completed are **not** run again on resume. The challenge will take about 10 minutes.

This challenge uses two terminals:

- *Aspire Terminal* — for running the `aspire run` command.
- *Curl Terminal* —  for trigging the start of the workflow.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

## 1. How to verify the durability

The demo has two mechanisms so you can verify the durability:

- **A deterministic crash gate.** Set the `CRASH_AFTER_AGENT_CALLS` environment variable before launching and the API hard-crashes (via `Environment.FailFast`) exactly once, right after the 3rd agent call (before logging it via the `RecordAgentCallActivity`). A marker file ensures the restarted process never crashes at the same point again during a subsequent run.
- **An agent-call ledger.** Every executed agent call appends one line to `agent-calls.log` — `<timestamp>  PR #<number>  <title>`. Recording happens inside a *checkpointed workflow activity*, so on resume a completed record is replayed from durable history and is **not** appended again. The finished ledger therefore holds each PR exactly once, with a visible time gap at the moment of restart.

## 2. Arm the crash gate and launch

Use the *Aspire Terminal* to the gate to crash after 3 agent calls (7 PRs total, so 4 remain for the resumed run:

```shell,run,copy
export CRASH_AFTER_AGENT_CALLS=3
```

 Start Aspire via the *Aspire Terminal*:
```shell,run,copy
aspire run
```

Open the *Aspire* tab and wait until the resources show **Running** in the Resources view. If a resource fails try to restart it in the dashboard using the.

Switch to the *Console* viewer in the Aspire Dashboard and select the `pr-digest` resource so you can inspect the log output of the workflow application.

## 3. Start a run and watch it crash

In the *Curl Terminal*, start a new workflow which will digest 7 PRs:

```curl,run
curl -X POST "http://localhost:5090/start" -H "Content-Type: application/json" -d '{
  "id": "run-crash",
  "repo": "dapr/dapr",
  "maxPrs": 7
}'
```

Watch the console logging in the *Aspire* tab. After the 3rd agent call the API process terminates by itself:

You'll see 7 of these statements which happen before the LLM call:

```text,nocopy
🤖 Analyzing PR #... with the PrAnalyzer agent
```

Only 2 of these which happen after the LLM call:

```text,nocopy
📒 Recorded agent call for PR #... (call #1 in this process).
📒 Recorded agent call for PR #... (call #2 in this process).
```

Followed by the crash:

```text,nocopy
💥 CRASH GATE TRIPPED after 3 agent call(s) — killing the process to simulate a crash.
```

> [!IMPORTANT]
> Refresh the *Editor* tab, so it detects the newly created file. You'll find the arrow on the right side of the tree view labelled AI-AGENTS-WORKFLOW.

Inspect the ledger in the *Editor* tab, it's located at `digest-out/agent-calls.log`. It contains 2 lines (the third agent call has been made but it has not been logged in this ledger):

```text,nocopy
2026-07-01T21:17:55.6157520Z	10093	perf: store raw perf reports per version and automate chart publishing
2026-07-01T21:17:55.6159890Z	9855	feat(outbox): add outboxInternalTopic metadata to override internal topic name
```

> [!NOTE]
> The actual PRs in this list might be different in your case, it depends which have been completed first by the Dapr workflow engine.

## 4. Disarm and restart

Stop Aspire in the *Aspire Terminal* with `Ctrl+C`, then disarm the gate and relaunch:

```shell,run,copy
unset CRASH_AFTER_AGENT_CALLS
aspire run
```

Aspire reconnects to the same Valkey container (its data volume persists), the workflow engine rehydrates workflow instance `run-crash`, and it **resumes automatically** — you do not call a start or resume endpoint again.

In the console logs in the *Aspire* tab you'll see `🤖 Analyzing PR #...` only for the PRs that hadn't finished; the already-analyzed ones stay silent because their results come from durable history.

## 5. Check the ledger

> [!IMPORTANT]
> Refresh the *Editor* tab, so it detects the updated file. You'll find the arrow on the right side of the tree view labelled AI-AGENTS-WORKFLOW.

Inspect the finished ledger in the *Editor* tab, it's located at `digest-out/agent-calls.log`:

```text,nocopy
2026-07-01T21:17:55.6157520Z	10093	perf: store raw perf reports per version and automate chart publishing
2026-07-01T21:17:55.6159890Z	9855	feat(outbox): add outboxInternalTopic metadata to override internal topic name
2026-07-01T21:23:38.4455520Z	9719	fix: make DeliverBulk fallthru consistent with Deliver for empty status
2026-07-01T21:23:38.5300310Z	10053	test: validate pubsub CloudEvent IDs are UUIDs
2026-07-01T21:23:40.3754570Z	9893	fix(api): standardize Configuration API errors
2026-07-01T21:23:40.3765620Z	9974	feat: search and vector blocks
2026-07-01T21:23:41.1990770Z	10054	Fix/workflow save before dispatch
```

Confirm:

1. **Exactly 7 lines — one per PR, no duplicate PR numbers.** The calls that completed before the crash were not re-run; their results came from durable history.
2. **A clear timestamp gap** between the pre-crash lines and the rest.

## 6. Read the PR digest

Now let's take a look at the result of the workflow. It's a ranked Markdown digest to an output directory (`/digest-out`) in the root of `PrDigest`.

Use the **Editor** tab to navigate to this folder and inspect the content of the generated output.

The digest ranks the pull requests by a computed **risk score** and includes, for each one:

- Rank, PR number, and title
- Risk score and flags (e.g. `many-files`, `large-diff`, `no-tests`, `no-linked-issue`)
- A summary and risk rationale — written by the `PrAnalyzer` agent
- The linked issue, if any

At the top is the headline written by the `Summarize` agent. The exact pull requests and scores depend on the bundled data snapshot.

## 7. Inspect the logs

Switch to the *Aspire* tab and open the **Structured Logs** view.

1. Filter to the `pr-digest` resource.
2. Look for the log statements that record the agent calls, there should only be 5 log entries, one for the agent call that succeeded but didn't record and four new agent calls.

```shell,nocopy
📒 Recorded agent call for PR #...
...
...
📒 Recorded agent call for PR #...
...
📒 Recorded agent call for PR #...
...
📒 Recorded agent call for PR #...
...
📒 Recorded agent call for PR #...
```

## 8. Recap

You saw how Dapr Workflow makes a Microsoft Agent Framework application reliable:

- Every agent call is a **checkpointed activity**. Its result is written to durable Valkey state the moment it completes.
- A crash mid-run **rehydrates from that state** and replays completed calls from history — so expensive, non-deterministic LLM calls are never repeated.
- A single `aspire run` orchestrates the API service, the Dapr sidecar, and the state store.

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
