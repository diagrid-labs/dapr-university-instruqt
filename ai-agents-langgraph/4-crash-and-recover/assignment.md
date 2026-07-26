You're going to crash a workflow on purpose, then prove Dapr picks up exactly where it left off. This challenge takes about 7 minutes.

## 1. Open crash_test.py

Open `crash_test.py` in the **Editor**. It's a simpler 3-node graph than `main.py`, with no LLM, just sequential steps: `check_venues` → `compare_options` → `confirm_booking`. That makes the recovery easy to see clearly.

## 2. Show the crash line

Look at line 30:

```python,nocopy
os._exit(1)  # 💥 Simulates a crash — comment out this line before the second run
```

`os._exit(1)` kills the Python process immediately. There's no exception, no cleanup, and no chance for Dapr to shut down gracefully. This simulates a hard infrastructure failure, like a pod eviction, an OOM kill, or a host reboot.

## 3. Start the crash test app

Use the **Terminal** window:

```bash,run
uv run dapr run --app-id langgraph-crash-test --resources-path ./resources -- python crash_test.py
```

Wait for `Uvicorn running on http://0.0.0.0:8001`.

## 4. Trigger the workflow

Use the **Terminal 2** window:

```bash,run
curl -X POST http://localhost:8001/run \
  -H "Content-Type: application/json" \
  -d '{"topic": "company gala on March 15"}'
```

## 5. Observe the crash

Switch to **Terminal**. You'll see:

```text,nocopy
>>> STEP 1: Checking venue availability for 'company gala on March 15'...
>>> STEP 1 COMPLETE: Grand Ballroom available on March 15 (2PM-6PM, 6PM-11PM)
>>> STEP 2: Comparing venue options...
❌ The App process exited with error code: 1
```

Step 1 finished and was checkpointed. Step 2 started, then the process died. There's no graceful shutdown message, just silence.

## 6. Verify state was persisted mid-crash

Use **Terminal 2**:

```bash,run
docker exec dapr_redis redis-cli keys "*crash-recovery-demo*"
```

Step 1's result is safely in Redis even though the process died right after starting step 2.

## 7. Comment out the crash

Back in the **Editor**, comment out line 30 in `crash_test.py`:

```python,nocopy
# os._exit(1)  # 💥 Simulates a crash — comment out this line before the second run
```

## 8. Restart the app

Use the **Terminal** window:

```bash,run
uv run dapr run --app-id langgraph-crash-test --resources-path ./resources -- python crash_test.py
```

Because `thread_id="crash-recovery-demo"` is hardcoded in `crash_test.py`, the workflow instance that was scheduled before the crash is still sitting in Redis under that same identity. You do **not** need to send another `curl` request. As soon as the app reconnects to its Dapr sidecar and re-registers the workflow, Dapr resumes that instance on its own.

## 9. Watch the recovery

Watch **Terminal**. You'll see step 2 run again, this time without crashing, followed by step 3, and the workflow completes:

```text,nocopy
>>> STEP 2: Comparing venue options...
>>> STEP 2 COMPLETE: Grand Ballroom (6PM-11PM) is the best option for 200 guests
>>> STEP 3: Confirming booking...
>>> STEP 3 COMPLETE: Booking confirmed: Grand Ballroom, March 15, 6PM-11PM
```

> [!IMPORTANT]
> Notice `STEP 1` does **not** print again. Its result already exists in Redis, so Dapr replays it from the checkpoint instead of re-running `check_venues`.

## 10. Recap

- Each LangGraph node runs as a checkpointed Dapr Workflow activity.
- `os._exit(1)` killed the process hard mid-flow, simulating a pod eviction or OOM kill.
- On restart, Dapr found the workflow instance by its deterministic ID and replayed history from the checkpoint store. That returned already-saved results without re-executing them, and the workflow resumed at step 2.
- The workflow completed even though the process that started it had died.

---

## Feedback and further learning

Congratulations! 🎉 You've completed the *Making LangGraph Agents Durable with Dapr Workflow* learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving it.

We have more ways for you to learn and share knowledge:

**Try another university track**
- [Deep issue investigation with DeepAgents and Dapr Workflow](https://www.diagrid.io/university/ai-agents-deepagents)

**Read more**
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).
- Read [Announcing Durable Workflow for Agents](https://www.diagrid.io/blog/durable-workflows-ai-agents).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#ai* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.
