In this challenge you'll run the _Supply Chain Auditor_ against a real Dependabot PR as a durable Dapr Workflow. The agent will crash on purpose partway through to simulate a serious issue that you might encounter in production. This challenge takes about 8 minutes to complete.

## 1. Look at the crash line

The durability demo ships with a deliberate crash, armed by default. Open `graph.py` in the **Editor** and find it in the `render_report` node:

```python,nocopy
if ledger.count() >= 2: os._exit(1)     # ← comment out for the resume run
```

By the time `render_report` runs, `gather_evidence` and `analyze` have each recorded one line in a stage *ledger* (`audit-out/audit-ledger.log`) — so `ledger.count()` is 2 and the process dies **right after** the expensive Claude call has completed and been checkpointed. `os._exit(1)` kills the process immediately — no cleanup, like a pod eviction or an OOM kill. The ledger exists just for demonstration purposes, it is not used by Dapr Worfklow since the workflow state is captured in a local Redis instance.

> [!IMPORTANT]
> Leave the crash line as-is for now. You'll comment it out in the next challenge to watch the workflow resume.

## 2. Run the audit

Use the **Terminal** to run the auditor. `dapr run` starts a Dapr sidecar and runs `python app.py` against it. All inputs (the PR to audit, your Anthropic key) come from `.env`:

```bash,run
uv run dapr run --app-id supply-chain-auditor-langgraph --resources-path ./resources -- python app.py
```

Watch the terminal:

1. `gather_evidence` resolves the package, fetches the release notes and diff from GitHub, and runs the heuristics.
2. `analyze` calls **Claude** to judge the notes against the diff.
3. `render_report` starts — and the process **dies by itself**:

```text,nocopy
❌  The App process exited with error code: 1
```

That crash landed *after* the Claude call completed. Look at the ledger — it holds the two stages that ran before the crash:

```bash,run
cat audit-out/audit-ledger.log
```

You'll see a `gather_evidence` line and an `analyze` line, each with a timestamp.

## 3. See the state that survived

Even though the process died, Dapr checkpointed each completed node to Redis. Confirm the workflow instance is still there by running this in the **Terminal**:

```bash,run
docker exec dapr_redis redis-cli keys "*audit-dapr-dapr-agents-635*"
```

You'll see keys for the workflow instance and its checkpointed activity results. This is exactly the state the next challenge resumes from — the completed `gather_evidence` and `analyze` results are saved, so they never have to run again.

## 4. How this works

1. Each LangGraph node (`gather_evidence`, `analyze`, `render_report`) is registered as a **Dapr Workflow activity**.
2. Before moving to the next node, Dapr checkpoints the previous node's result to the Redis state store (`resources/workflowstate.yaml`, `actorStateStore: "true"`).
3. `app.py` runs the workflow under a **deterministic instance ID** derived from the PR — `audit-dapr-dapr-agents-635-<package>` — so a later run can find this exact instance instead of starting a new one.
4. `os._exit(1)` killed the process after `analyze` was checkpointed but before `render_report` finished, leaving the instance **in-flight** in Redis.

---

The audit crashed before it could produce a report — but nothing that already ran was lost. In the final challenge you'll comment out the crash, re-run the same command, and watch Dapr resume the workflow without re-fetching from GitHub or calling Claude again.
