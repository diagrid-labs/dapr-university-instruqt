This is the payoff. You're going to crash the investigation on purpose, then prove the workflow picks up exactly where it left off.

## 1. Find the crash line

Open `tools_crash.py` in the **Editor**. This is the same `get_comments` tool as before, with one line added — **line 34**:

```python,nocopy
os._exit(1)  # Simulates a crash — comment out this line before the second run
```

`investigate.py` (the active copy of `investigate-crash.py`) imports tools from `tools_crash.py`. `os._exit(1)` kills the Python process immediately — no exception, no cleanup, no chance for Dapr to gracefully shut down. This simulates a hard infrastructure failure: a pod eviction, an OOM kill, a host reboot.

The script also uses a `crash_state.json` file to persist the Dapr workflow ID across restarts. On the first run it writes this file when the `workflow_started` event fires; on the second run it detects the file and polls the **existing** workflow rather than starting a new one.

## 2. Trigger the crash

Use the **Terminal** window to start the investigation:

```bash,run
uv run dapr run --app-id deepagent --resources-path ./resources -- python investigate.py --issue 1833
```

Watch the terminal. The agent calls `get_issue` first — that activity completes and gets checkpointed. The workflow ID is saved to `crash_state.json`. Then the agent calls `get_comments`, and the process dies. The terminal output stops; there is no graceful shutdown message.

Verify the crash was recorded:

```bash,run
cat crash_state.json
```

```text,nocopy
{
  "workflow_scheduled": true,
  "workflow_id": "graph-investigation-1833-<uuid>",
  "run_count": 1
}
```

> [!NOTE]
> The `workflow_id` is the handle to the in-flight Dapr workflow. The script uses it on the next run to reconnect to the same instance rather than starting a new one.

## 3. Remove the crash

Back in the **Editor**, comment out line 34 in `tools_crash.py`:

```python,nocopy
# os._exit(1)  # Simulates a crash — comment out this line before the second run
```

## 4. Run again — watch the recovery

Use the **Terminal** window to restart the investigation:

```bash,run
uv run dapr run --app-id deepagent --resources-path ./resources -- python investigate.py --issue 1833
```

Watch closely: the script detects `crash_state.json`, skips `run_async()`, and polls the **same** workflow instance by its saved ID. The Dapr Workflow engine replays history up to the last checkpoint and continues execution from `get_comments` — `get_issue` is **not** called again. Execution continues from where it crashed, and the investigation completes.

> [!IMPORTANT]
> The key proof is in the logs: you will not see `get_issue` being executed again. Dapr's replay mechanism skips any activity whose result is already in the checkpoint store.

## 5. Read the report

```bash,run
cat investigation-1833.md
```

A complete report, even though the process that produced it died and restarted halfway through.

## 6. How this works

1. On the first run, `run_async()` starts a new Dapr Workflow and saves the workflow ID to `crash_state.json` when `workflow_started` fires.
2. `os._exit(1)` kills the process hard — the activity result for `get_comments` is not written, but `get_issue`'s result is already in Redis.
3. On the second run, the script detects `crash_state.json` and skips `run_async()`. Instead it calls `poll_for_completion()` using the saved workflow ID.
4. Dapr reconnects to the existing workflow instance, replays checkpointed activities (returning their saved results without re-executing them), and resumes at `get_comments`.
5. The investigation completes and `investigation-1833.md` is written to disk.

That's the entire point of backing a long-running agent with Dapr: a crash costs you a restart, not the work.

---

You've completed the track. From here you could add sub-agents for parallel investigation, point the same pattern at a different issue, or wire in Dapr's Conversation API for additional LLM-call resiliency.
