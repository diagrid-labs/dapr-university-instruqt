You're going to crash a workflow on purpose, then prove Dapr Workflow picks up exactly where it left off. This challenge takes about 8 minutes.

> [!IMPORTANT]
> This challenge uses two terminals: *Terminal 1* for running the app, and *Terminal 2* for triggering it via HTTP. When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

## 1. Open crash_test.py

Open `crash_test.py` in the **Editor**. It's a simpler graph than `main.py`: three nodes, no model, just sequential steps.

1. `check_venues` checks venue availability. Instant, and it completes.
2. `compare_options` compares options, slowly. This is where you'll crash the app.
3. `confirm_booking` confirms the booking. Instant.

The order is the whole point. `check_venues` finishes and its result is checkpointed *before* `compare_options` starts, so the crash lands between two known points. After the restart you'll be able to see that only the interrupted node ran again.

## 2. Find the slow step

Look at `compare_options`, starting at line 50. Two lines carry the demo:

```python,nocopy
    delay = int(os.environ.get("CRASH_DELAY_SECONDS", "30"))
```

```python,nocopy
    time.sleep(delay)
```

`compare_options` deliberately takes about 30 seconds. Without that delay all three nodes would finish in milliseconds and there would be no window in which to crash anything.

## 3. Find the kill switch

Look at lines 286-292:

```python,nocopy
@app.post("/crash/kill")
async def crash_kill():
    print(">>> /crash/kill: killing this process to simulate a worker crash", flush=True)
    # os._exit, not sys.exit: sys.exit raises SystemExit, which unwinds through uvicorn and
    # runs the shutdown paths on the way out. That is a controlled exit, which is the
    # opposite of what this demo simulates.
    os._exit(1)
```

`os._exit(1)` kills the Python process immediately. No exception handling, no cleanup, no chance for Dapr to shut down gracefully. That simulates a hard infrastructure failure: a pod eviction, an OOM kill, a host reboot.

You won't call `/crash/kill` yourself. The request you're about to send carries a `kill_after_seconds` field, which arms that same `os._exit(1)` on a timer *inside* `compare_options`, so the app crashes itself at a known point and you don't have to race a 30 second window by hand. Look at lines 138-150 for the request shape (comments trimmed here):

```python,nocopy
class CrashRunRequest(BaseModel):
    id: Optional[str] = None
    topic: str = "company gala on March 15"
    kill_after_seconds: Optional[int] = None
```

`id` is the workflow instance ID, and **you** choose it. That's what lets you find the same run again after the process that started it is gone.

## 4. Start the crash test app

Use the **Terminal 1** window:

```bash,run
uv run dapr run --app-id langgraph-crash-test --resources-path ./resources -- python crash_test.py
```

Wait for `Uvicorn running on http://0.0.0.0:8001`.

## 5. Start a run that crashes itself

Use the **Terminal 2** window:

```bash,run
curl -X POST http://localhost:8001/crash/run \
  -H "Content-Type: application/json" \
  -d '{"id": "gala-42", "topic": "company gala on March 15", "kill_after_seconds": 8}'
```

Three things to notice in that body:

- `id` names the workflow instance `gala-42`. You own it, so you can come back to it later.
- `kill_after_seconds: 8` tells the app to kill itself 8 seconds into `compare_options`, comfortably inside that node's 30 second window.
- The request **blocks** until the run finishes, which it never will, because the app dies first.

After about 8 seconds `curl` reports something like `curl: (56) Recv failure: Connection reset by peer`. That's the point. A process that answers politely hasn't crashed.

## 6. Observe the crash

Switch to **Terminal 1**. You'll see:

```text,nocopy
>>> STEP 1: Checking venue availability for 'company gala on March 15'...
>>> STEP 1 COMPLETE: Grand Ballroom available on March 15 (2PM-6PM, 6PM-11PM)
>>> STEP 2: Comparing venue options over ~30s, but this process kills itself 8s into the run, as asked by kill_after_seconds. It resumes on restart.
>>> crash: killing this process 8s into the run, as asked by kill_after_seconds
❌  The App process exited with error code: 1
```

Step 1 finished and was checkpointed. Step 2 started, then the process died 8 seconds in.

> [!IMPORTANT]
> Wait until the terminal returns to the prompt, or press `Ctrl+C` if it doesn't. The Dapr sidecar shuts down a moment after the app process dies, and restarting the app in the next step while the old sidecar still holds its ports fails with an "address already in use" error.

## 7. Restart the app

Use the **Terminal 1** window:

```bash,run
uv run dapr run --app-id langgraph-crash-test --resources-path ./resources -- python crash_test.py
```

You do **not** need to send another request. The workflow instance `gala-42` was never in the process you killed. It lives in Redis, and as soon as the restarted app re-registers its workflow with the Dapr sidecar, Dapr hands the instance back and the run resumes on its own.

## 8. Watch the recovery

Watch the logs in **Terminal 1**. Step 2 runs again from the beginning, and this time it is allowed to finish, so give it about 30 seconds:

```text,nocopy
>>> STEP 2: Comparing venue options over ~30s. KILL THE APP NOW to test crash recovery (POST /crash/kill, or kill -9). It resumes on restart.
>>> STEP 2 COMPLETE: Grand Ballroom (6PM-11PM) is the best option for 200 guests
>>> STEP 3: Confirming booking...
>>> STEP 3 COMPLETE: Booking confirmed: Grand Ballroom, March 15, 6PM-11PM
```

The step 2 line reads differently this time. This is a fresh process that was never armed with `kill_after_seconds`, so it prints its generic prompt instead. **Ignore the `KILL THE APP NOW` instruction** — you have already crashed this run once, and this time it is meant to finish.

> [!IMPORTANT]
> Notice `STEP 1` does **not** print again. Its result already exists in Redis, so Dapr replays it from the checkpoint instead of re-running `check_venues`. Only the node that was interrupted runs twice.

## 9. Collect the answer

The run recovered on its own, but the crash also killed the connection that was waiting for its result. Send the same request once more, this time **without** `kill_after_seconds`, to attach to the run that already finished.

Use the **Terminal 2** window:

```bash,run
curl -X POST http://localhost:8001/crash/run \
  -H "Content-Type: application/json" \
  -d '{"id": "gala-42", "topic": "company gala on March 15"}'
```

Because the instance `gala-42` already exists, this attaches to it instead of starting a second run. **Terminal 1** says so:

```text,nocopy
>>> Attaching to the existing run gala-42 instead of starting a second one
```

And `curl` returns the recorded final state of the graph, including all three step results.

```json,nocopy
{
  "id": "gala-42",
  "result": {
    "topic": "company gala on March 15",
    "results": [
      "Grand Ballroom available on March 15 (2PM-6PM, 6PM-11PM)",
      "Grand Ballroom (6PM-11PM) is the best option for 200 guests",
      "Booking confirmed: Grand Ballroom, March 15, 6PM-11PM"
    ]
  },
  "message": null
}
```

## 10. Recap

- Each LangGraph node runs as a checkpointed Dapr Workflow activity.
- `kill_after_seconds` armed the same `os._exit(1)` that `POST /crash/kill` uses, killing the process hard in the middle of step 2.
- The workflow instance survived the process, because it lives in Redis rather than in memory.
- On restart, Dapr found the instance by the ID you gave it and replayed history from the checkpoint store. Step 1's saved result came back without re-executing the node, and the workflow resumed at step 2.
- The workflow completed even though the process that started it had died, and you collected its answer from a connection that didn't exist when the run began.

---

## Feedback and further learning

Congratulations! 🎉 You've completed the *Making LangGraph Agents Durable with Dapr Workflow - Schedule Planner* learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving it.

We have more ways for you to learn and share knowledge:

**Try another university track**
- [Deep issue investigation with DeepAgents and Dapr Workflow](https://www.diagrid.io/university/ai-agents-deepagents)

**Read more**
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).
- Read [Announcing Durable Workflow for Agents](https://www.diagrid.io/blog/durable-workflows-ai-agents).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#ai* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.
