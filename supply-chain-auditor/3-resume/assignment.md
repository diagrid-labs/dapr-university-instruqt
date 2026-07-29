The audit crashed in the last challenge, but Dapr checkpointed every completed step to Redis. In this final challenge you'll comment out the crash and re-run the exact same command — and watch the workflow resume instead of starting over. This challenge takes about 8 minutes to complete.

## 1. Disarm the crash

Open `graph.py` in the **Editor** and comment out the crash line in `render_report`:

```python,nocopy
# if ledger.count() >= 2: os._exit(1)     # ← comment out for the resume run
```

Save the file.

## 2. Re-run the exact same command

Use the **Terminal** to run the same command as before — the inputs still come from `.env`:

```bash,run
uv run dapr run --app-id supply-chain-auditor-langgraph --resources-path ./resources -- python app.py
```

Watch the terminal closely. This time `app.py` derives the same deterministic instance ID, finds the instance **still in flight** in Redis, and polls it to completion instead of scheduling a new run. You'll see a log line like:

```text,nocopy
Workflow audit-dapr-dapr-agents-635-... in flight (WorkflowStatus.RUNNING) — resuming by polling
```

Dapr replays `gather_evidence` and `analyze` from durable history — returning their saved results **without re-executing them** — and runs only `render_report`. The workflow reaches **Completed** and the Markdown report is printed (a dry-run, since no `GITHUB_TOKEN` is set).

## 3. Prove the analyze call ran exactly once

Look at the ledger again:

```bash,run
cat audit-out/audit-ledger.log
```

You should see **exactly three lines** — `gather_evidence`, `analyze`, `render_report`, each once:

- The `analyze` line has the timestamp from the **first** run (before the crash). It was **not** written again on resume — proof the Claude call ran exactly once.
- There's a visible **time gap** before the `render_report` line: the wall-clock cost of the crash and restart, inside one logical workflow run.

That's the whole point: a crash cost a restart, not the work — and not a second Claude call.

## 4. How this works

1. On the first run, `app.py` found no instance under `audit-dapr-dapr-agents-635-<pkg>` and scheduled a fresh workflow.
2. `os._exit(1)` killed the process after `analyze` was checkpointed, leaving the instance in-flight.
3. On this run, `app.py` derived the same ID, found the instance still `RUNNING`, and polled it to completion (`resume_or_invoke` in `runtime.py`) instead of starting over.
4. Dapr rehydrated the instance, replayed the checkpointed `gather_evidence` and `analyze` results from history, and resumed at `render_report`. Neither the GitHub fetch nor the Claude call was repeated.

## 5. Reset for a fresh run (optional)

To run the whole demo again from scratch, purge the workflow state **and** the ledger, then re-arm the crash by un-commenting the line in `graph.py`:

```bash,run
docker exec dapr_redis redis-cli flushall
rm -f audit-out/audit-ledger.log
```

> [!NOTE]
> The ledger must be removed too — stale lines would push `ledger.count()` to 2 and trip the crash gate before the pipeline even reaches `render_report`.

## Recap

You crashed a running audit on purpose and watched it recover without losing work:

- Each pipeline node is a **checkpointed Dapr Workflow activity**; its result is written to durable Redis state the moment it completes.
- `os._exit(1)` killed the process hard after the expensive `analyze` (Claude) call had been checkpointed.
- On restart, `app.py` reconnected to the **same workflow instance by its deterministic ID**, and Dapr **replayed history from the checkpoint store** — returning saved results without re-executing them — and resumed at `render_report`. Claude was never called twice.
- The audit completed and produced a full report, even though the process that started it had died.

## Feedback and further learning

Congratulations! 🎉 You've completed the *Audit dependency bumps for supply-chain attacks with Dapr Workflow* learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving it.

We have more ways for you to learn and share knowledge:

**Try another university track**
- [Make DeepAgents reliable with Dapr Workflow](https://www.diagrid.io/university)
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Read more**
- Read [Announcing Durable Workflow for Agents](https://www.diagrid.io/blog/durable-workflows-ai-agents).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#ai* and language channels.
