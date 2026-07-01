In this challenge you'll prove the durability of the application. You'll interrupt the workflow with a real process crash, restart it, and prove that the `PrAnalyzer` agent calls that already completed are **not** run again on resume. The challenge will take about 8 minutes.

This challenge uses two terminals:

- *Aspire Terminal* — for running the `aspire run` command.
- *Curl Terminal* —  for trigging the start of the workflow.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

## 1. How it's made provable

The demo has two mechanisms so you can verify the durability:

- **A deterministic crash gate.** Set the `CRASH_AFTER_AGENT_CALLS` environment variable before launching and the API hard-crashes (via `Environment.FailFast`) exactly once, right after the 3rd agent call. A marker file ensures the restarted process never crashes at the same point again.
- **An agent-call ledger.** Every executed agent call appends one line to `agent-calls.log` — `<timestamp>  PR #<number>  <title>`. Recording happens inside a *checkpointed workflow activity*, so on resume a completed record is replayed from durable history and is **not** appended again. The finished ledger therefore holds each PR exactly once, with a visible time gap at the moment of restart.

## 2. Arm the crash gate and launch

Arm the gate to crash after 3 agent calls (7 PRs total, so 4 remain for the resumed run) and start Aspire. Run in the *Aspire Terminal*:

```shell,run,copy
export CRASH_AFTER_AGENT_CALLS=3
aspire run
```

Wait until the resources show **Running** in the *Aspire* tab. Switch to the *Console* viewer in the Aspire Dashboard and select the `pr-digest` resource so you can inspect the log output.

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

Inspect the ledger in the *Editor* tab, it's located at `digest-out/agent-calls.log`. It contains 2 lines (the call that tripped the gate is recorded only after restart, so it's never duplicated):

```text,nocopy
2026-07-01T21:17:55.6157520Z	10093	perf: store raw perf reports per version and automate chart publishing
2026-07-01T21:17:55.6159890Z	9855	feat(outbox): add outboxInternalTopic metadata to override internal topic name
```

## 4. Disarm and restart

Stop Aspire in the *Aspire Terminal* with `Ctrl+C`, then disarm the gate and relaunch:

```shell,run,copy
unset CRASH_AFTER_AGENT_CALLS
aspire run
```

Aspire reconnects to the same Valkey container (its data volume persists), the workflow engine rehydrates instance `run-crash`, and it **resumes automatically** — you do not call a start or resume endpoint. In the console logs in the *Aspire* tab you'll see `🤖 Analyzing PR #...` only for the PRs that hadn't finished; the already-analyzed ones stay silent because their results come from durable history.

## 5. Check the ledger

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
2. **A clear timestamp gap** between the pre-crash lines and the rest — the wall-clock cost of the crash and restart, inside a single logical workflow run.

## 6. Read the PR digest

Now let's take a look at the result of the workflow. It's a ranked Markdown digest to an output directory (`/digest-out`) in the root of `PrDigest`.

> [!IMPORTANT]
> Refresh the *Editor* tab with the circular arrow button, so it detects the newly created file.

Use the **Editor** tab to navigate to this folder and inspect the content of the generated output.

The digest ranks the pull requests by a computed **risk score** and includes, for each one:

- Rank, PR number, and title
- Risk score and flags (e.g. `many-files`, `large-diff`, `no-tests`, `no-linked-issue`)
- A summary and risk rationale — written by the `PrAnalyzer` agent
- The linked issue, if any

At the top is the headline written by the `Summarize` agent. The exact pull requests and scores depend on the bundled data snapshot.

---

You've proven the durability of Dapr Workflow: a crash mid-run cost you nothing in repeated LLM calls. In the final challenge you'll inspect the workflow's traces and recap what you learned.
