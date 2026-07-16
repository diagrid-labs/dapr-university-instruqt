In this final challenge you'll prove the durability of the application. You'll interrupt the workflow with a real process crash, restart it, and prove that the `PrAnalyzer` agent calls that already completed are **not** run again on resume. The challenge will take about 10 minutes.

This challenge uses two terminals:

- *Aspire Terminal* — for running the `aspire run` command.
- *Curl Terminal* —  for trigging the start of the workflow.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

## 1. How to verify the durability

The demo has two mechanisms so you can verify the durability:

- **A one-line crash toggle.** `RecordAgentCallActivity.cs` contains a single `Environment.FailFast` line — armed (uncommented) by default — that hard-crashes the process once a couple of agent calls have already been recorded (so the crash lands partway through the run). There's no environment variable and no marker file, so you disable the crash for the resume run by commenting the line out.
- **An agent-call ledger.** Every executed agent call appends one line to `agent-calls.log` — `<timestamp>  PR #<number>  <title>`. Recording happens inside a *checkpointed workflow activity*, so on resume a completed record is replayed from durable history and is **not** appended again. The finished ledger therefore holds each PR exactly once, with a visible time gap at the moment of restart.

## 2. Launch

The crash is already armed in the code, so there's nothing to set up — the app will crash partway through this first run, once a couple of PRs have been recorded. If you'd like to see the toggle, open `PrDigest.ApiService/Activities/RecordAgentCallActivity.cs` in the *Editor* tab and find the `Environment.FailFast(...)` line inside `RunAsync`.

Start Aspire via the *Aspire Terminal*:
```shell,run,copy
aspire run
```

Open the *Aspire* tab and wait until the resources show **Running** in the Resources view. If a resource fails try to restart it in the dashboard using the start/stop actions.

## 3. Start a run and watch it crash

Switch to the *Console* viewer in the Aspire Dashboard and select the `pr-digest` resource so you can inspect the log output of the workflow application.

In the *Curl Terminal*, start a new workflow which will digest 7 PRs:

```curl,run
curl -X POST "http://localhost:5090/start" -H "Content-Type: application/json" -d '{
  "id": "run-crash",
  "repo": "dapr/dapr",
  "maxPrs": 7
}'
```

Watch the console logging in the *Aspire* tab.

You'll see 7 of these statements which happen before the LLM call:

```text,nocopy
🤖 Analyzing PR #... with the PrAnalyzer agent
...
Calling LLM for agent 'PrAnalyzerAgent'
```

And two of these log statements which happen after the LLM call — the crash trips once two calls have been recorded (which two depends on the concurrent fan-out):

```text,nocopy
📒 Recorded agent call for PR #...
```

Followed by the crash. `Environment.FailFast` terminates the process immediately, so instead of a normal log line you'll see a fatal-error message and stack trace, and the `pr-digest` resource turns red (Exited) in the dashboard:

```text,nocopy
Simulated crash — demonstrating durable resume.
   at System.Environment.FailFast(System.String)
   ...
```

> [!IMPORTANT]
> Refresh the *Editor* tab, so it detects the newly created file. You'll find the arrow on the right side of the tree view labelled AI-AGENTS-WORKFLOW.

Inspect the ledger in the *Editor* tab, it's located at `digest-out/agent-calls.log`. It contains only the calls recorded before the crash, two lines:

```text,nocopy
2026-07-01T21:17:55.6157520Z	10093	perf: store raw perf reports per version and automate chart publishing
2026-07-01T21:17:55.6159890Z	9855	feat(outbox): add outboxInternalTopic metadata to override internal topic name
```

> [!NOTE]
> The exact PRs will differ in your case — the PRs are analyzed concurrently, so it depends which ones the Dapr workflow engine completed first. The crash trips once two calls have been recorded, so you'll see about two lines; the PR whose recording was interrupted is written only on the resumed run.

## 4. Disarm and restart

Stop Aspire in the *Aspire Terminal* with `Ctrl+C`.

Now disarm the crash so the resumed run can finish. In the *Editor* tab, open `PrDigest.ApiService/Activities/RecordAgentCallActivity.cs` and **comment out** the `Environment.FailFast` line inside `RunAsync` by prefixing it with `//`:

```csharp,nocopy
// if (ledger.CountEntries() >= 2) Environment.FailFast("Simulated crash — demonstrating durable resume.");
```

Save the file (it should auto-save).

> [!IMPORTANT]
> There is no marker file to stop a second crash — if you skip this step, the resumed run will crash again immediately (the ledger already holds two or more lines).

Relaunch via the *Aspire Terminal*:

```shell,run,copy
aspire run
```

Aspire reconnects to the same Valkey container (its data volume persists), the workflow engine rehydrates workflow instance `run-crash`, and it **resumes automatically** — you do not call a start or resume endpoint again.

## 5. Check the ledger

> [!IMPORTANT]
> Refresh the *Editor* tab, so it detects the updated file. You'll find the circular arrow on the right side of the tree view labelled AI-AGENTS-WORKFLOW.

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

Switch to the *Aspire* tab and open the **Console** view.

1. Filter to the `pr-digest` resource.
2. Look for the log statements that record the agent calls. On the resumed run you'll only see them for the PRs that hadn't been called before the crash:

```text,nocopy
Calling LLM for agent 'PrAnalyzerAgent'  ...
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
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Read more**
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).
- Read [Announcing Durable Workflow for Agents](https://www.diagrid.io/blog/durable-workflows-ai-agents).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#ai* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.
