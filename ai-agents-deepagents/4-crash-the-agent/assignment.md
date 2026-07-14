In this challenge you're going to crash the investigation on purpose, then prove the workflow picks up exactly where it left off. This challenge takes about 5 minutes to complete.

## 1. Find the crash line

Open `tools_crash.py` in the **Editor**. This is the same `get_comments` tool as before, with one line added — **line 23**:

```python,nocopy
os._exit(1)  # Simulates a crash — comment out this line before the second run
```

`investigate-crash.py` imports tools from `tools_crash.py`. `os._exit(1)` kills the Python process immediately — no exception, no cleanup, no chance for Dapr to gracefully shut down. This simulates a hard infrastructure failure: a pod eviction, an OOM kill, a host reboot.

`investigate-crash.py` derives a deterministic workflow ID from the issue number — `investigation-1833` — so a restart can find the exact same Dapr workflow instance. Dapr's state store is the single source of truth for whether an investigation has started, is still running, or has finished.

## 2. Trigger the crash

Use the **Terminal** window to start the investigation:

```bash,run
uv run dapr run --app-id deepagent --resources-path ./resources -- python investigate-crash.py --issue 1833
```

Watch the terminal. The script logs `No existing workflow for investigation-1833 — starting fresh` and schedules the workflow. The agent calls `get_issue` first — that activity completes and gets checkpointed. Then the agent calls `get_comments`, and the process dies. The terminal output stops; there is no graceful shutdown message.

Verify Dapr persisted the workflow — even though the process died and no local file was written:

```bash,run
docker exec dapr_redis redis-cli keys "*investigation-1833*"
```

You'll see keys for the `investigation-1833` workflow instance. Dapr wrote the workflow's progress (including `get_issue`'s checkpointed result) to Redis on its own.

## 3. Remove the crash

Back in the **Editor**, comment out line 23 in `tools_crash.py`:

```python,nocopy
# os._exit(1)  # Simulates a crash — comment out this line before the second run
```

## 4. Run again — watch the recovery

Use the **Terminal** window to restart the investigation:

```bash,run
uv run dapr run --app-id deepagent --resources-path ./resources -- python investigate-crash.py --issue 1833
```

Watch closely. This time the script logs `Found existing workflow investigation-1833: WorkflowStatus.RUNNING`, skips `run_async()`, and calls `poll_for_completion()` — which waits on the **same** workflow instance using Dapr's built-in waits (`Workflow is running — waiting for it to finish...`). The Dapr Workflow engine replays history up to the last checkpoint and continues execution from `get_comments` — `get_issue` is **not** called again. Execution continues from where it crashed, and the investigation completes.

> [!IMPORTANT]
> The key proof is in the logs: you will not see `get_issue` being executed again. Dapr's replay mechanism skips any activity whose result is already in the checkpoint store.

## 5. Read the report

Refresh the *Editor* tab, then navigate to `investigation-1833.md` to open it.

It shows a complete report, even though the process that produced it died and restarted halfway through.

## 6. How this works

1. On the first run, the script queries Dapr for the `investigation-1833` instance, finds nothing, and calls `run_async()` to start a new Dapr Workflow under that deterministic ID.
2. `os._exit(1)` kills the process hard — the activity result for `get_comments` is not written, but `get_issue`'s result is already in Redis.
3. On the second run, the script derives the same ID, queries Dapr, and finds the instance still `RUNNING`. Instead of starting a new workflow, it calls `poll_for_completion()`, which waits on that instance with `wait_for_workflow_start()` and `wait_for_workflow_completion()`.
4. Dapr reconnects to the existing workflow instance, replays checkpointed activities (returning their saved results without re-executing them), and resumes at `get_comments`.
5. The investigation completes and `investigation-1833.md` is written to disk.

That's the entire point of backing a long-running agent with Dapr: a crash costs you a restart, not the work. And because the workflow ID is derived from the issue number, no bookkeeping file is needed — Dapr's state store holds everything.

> [!NOTE]
> To run the whole demo again from scratch, flush Dapr's state so `investigation-1833` no longer exists:
> ```bash,nocopy
> docker exec dapr_redis redis-cli flushall
> ```
> Re-running with the crash removed while the instance is still `COMPLETED` just rewrites the report from Dapr's stored output — it won't investigate again.

## Recap

You crashed a running investigation on purpose and watched it recover without losing work:

- Each tool call is a **checkpointed activity**. Its result is written to durable state the moment it completes.
- `os._exit(1)` killed the process hard mid-run, simulating a pod eviction or OOM kill.
- On restart, the script reconnected to the **same workflow instance by its deterministic ID**, and Dapr's Workflow engine **replayed history from the checkpoint store** — returning already-saved results without re-executing them — and resumed exactly where it crashed. `get_issue` was never called twice.
- The investigation completed and produced a full report, even though the process that started it had died — with no local state file involved.

That combination turns a long-running agent into a fault-tolerant application you can crash without losing — or paying for — completed work twice.

## Feedback and further learning

Congratulations! 🎉 You've completed the *Make DeepAgents Reliable with Dapr Workflow* learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving it.

We have more ways for you to learn and share knowledge:

**Try another university track**
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Read more**
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).
- Read [Announcing Durable Workflow for Agents](https://www.diagrid.io/blog/durable-workflows-ai-agents).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#ai* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.
