The baseline agent worked, but everything it did lived in process memory. In this final challenge you'll wrap the exact same agent in a **Dapr Workflow**, so its state and progress are persisted as it runs. This challenge takes about 5 minutes to complete.

## 1. Inspect the durable version

Open investigate-durable.py in the **Editor**. The agent definition is unchanged — same tools, same system prompt. What's new is the entry point:

```python,nocopy
from diagrid.agent.deepagents import DaprWorkflowDeepAgentRunner

runner = DaprWorkflowDeepAgentRunner(
    agent=agent,
    name="issue-investigation",
    max_steps=50,
)
```

Instead of `agent.invoke(...)`, the script now calls `runner.start()` and streams events from `runner.run_async(...)`. Under the hood, every tool call the agent makes becomes a **Dapr Workflow activity** — and Dapr checkpoints each activity's result before moving to the next one.

## 2. Inspect the state store

Open `resources/statestore.yaml` in the **Editor**:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: agent-memory
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

This is a Redis-backed Dapr state store named `agent-memory` — the name the DeepAgents Dapr integration looks for by convention. `actorStateStore: "true"` means it also backs the Dapr Workflow state.

## 3. Run the durable investigation

Use the **Terminal** window to run the agent with Dapr:

```bash,run
uv run dapr run --app-id deepagent --resources-path ./resources -- python investigate-durable.py --issue 1833
```

Watch the terminal — you'll see the same tool calls as challenge 2, but now interleaved with `Event: workflow_started`, `Event: workflow_status_changed`, and `Event: workflow_completed` as Dapr tracks the run.

## 4. Read the report

Refresh the *Editor* tab, then navigate to `investigation-1833.md` to open it.

This is the same report as challenge 2 — but this time, if the process had died halfway through, the work up to that point wouldn't be lost. That's exactly what you'll prove next.

## 5. How this works

1. `DaprWorkflowDeepAgentRunner.start()` registers the agent graph as a Dapr Workflow and starts the actor runtime.
2. Each node in the LangGraph state machine (tool call, model call, middleware) is wrapped as a Dapr Workflow activity.
3. Before Dapr moves to the next activity, it writes the result of the current one to the Redis state store.
4. If the process dies, the workflow engine can replay history up to the last checkpoint and resume from there on restart.

> [!IMPORTANT]
> Use `Ctrl+C` in the **Terminal** window to stop the Dapr application before moving on.

---

You've now run the same investigation backed by a Dapr Workflow, with every step checkpointed to Redis. Let's move on to challenge 4 where you'll prove this works by intentionally crashing the process mid-investigation.
