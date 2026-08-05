Time to run the Schedule Planner for real and watch the durability layer at work. This challenge takes about 6 minutes.

## 1. Start the agent with Dapr

Use the **Terminal** window:

```bash,run
uv run dapr run --app-id schedule-planner --resources-path ./resources -- python main.py
```

This starts the Dapr sidecar alongside the FastAPI server. Wait until you see `Uvicorn running on http://0.0.0.0:8005` before continuing.

## 2. Trigger a run

Use the **Terminal 2** window:

```bash,run
curl -i -X POST http://localhost:8005/agent/run \
  -H "Content-Type: application/json" \
  -d '{"task": "Check if the Grand Ballroom is available on March 15th"}'
```

## 3. Observe the log stream

Switch back to **Terminal** and watch the output. You'll see `Event: workflow_started`, the `check_availability` tool being invoked, and `Event: workflow_completed` once the agent has an answer.

## 4. Inspect the state store

Open `resources/wfstatestore.yaml` in the **Editor**:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: agent-workflow
spec:
  type: state.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
  - name: actorStateStore
    value: "true"
```

This is a Redis-backed Dapr state store. `actorStateStore: "true"` is what makes it usable by the Dapr Workflow engine. Workflows run on Dapr's actor runtime under the hood, and this component is where that runtime persists its state.

## 5. Peek into Redis

Use **Terminal 2**:

```bash,run
docker exec dapr_redis redis-cli keys "*schedule-planner*"
```

These keys are the workflow instance state, its activity results, and its execution history. All of it was written to Redis as the graph ran, before you even looked.

## 6. How this works

1. Each LangGraph node (`agent`, `tools`) runs as a Dapr Workflow activity.
2. Every activity's result is checkpointed to Redis before the next node runs.
3. The workflow can be replayed from any checkpoint. Dapr doesn't need to trust that anything is still in memory.
4. That's what makes crash recovery possible, which you'll prove in the next challenge.

## 7. Stop the app

Use `Ctrl+C` in the **Terminal** window to stop the Dapr application before moving on.

---

You've seen the agent run as a durable workflow and inspected its checkpointed state. Let's move on to challenge 4 where you'll crash it on purpose.
