This challenge introduces the DurableAgent, a workflow-native agent backed by the Dapr Workflow engine. Every step of the agent’s execution is persisted to durable storage, allowing long-running interactions to survive interruptions. The agent exposes an HTTP endpoint to start a new workflow and provides a way to query progress or retrieve the final result at any time.

## 1. Durable Agent with REST endpoint

The Durable Agent is a powerful and resilient agent type, designed for production-level AI applications. The Durable Agent:

1. **Implements the Workflow Pattern**: Uses Dapr's workflow engine to execute tasks in a durable, recoverable manner
2. **Preserves State Across Failures**: Stores all conversation state and execution progress in persistent storage
3. **Manages Complex Tool Interactions**: Orchestrates tool calls with proper error handling and retry logic
4. **Supports Multi-Agent Communication**: Can broadcast messages to other agents and receive responses
5. **Exposes Service APIs**: Provides REST endpoints to trigger workflows and check their status

This makes the DurableAgent ideal for mission-critical applications that need to remain functional even when facing system failures, network issues, or process restarts.

## 2. Explore the DurableAgent

Use the **Editor** window to examine the durable agent implementation in the `02_durable_agent_http.py` file.

The agent exposes a REST endpoint, accepts a prompt, and returns a workflow ID that represents a durable execution. You can query this workflow at any time—even after stopping and restarting the agent—and it will resume exactly where it left off. The agent performs an LLM call and a tool call as part of completing the workflow and produces a final result.

### Agent Memory

```python,nocopy
memory=AgentMemoryConfig(
    store=ConversationDaprStateMemory(
        store_name="agent-memory",
    )
),
```

This configures the agent to store its memory in a Dapr state store, enabling it to remember context across sessions and survive restarts.

**Component Configuration (agent-memory.yaml)**:

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
```

### State Store for Workflow Orchestration

```python,nocopy
state=AgentStateConfig(
    store=StateStoreService(store_name="agent-workflow"),
),
```

These parameters configure where the agent stores its execution state for workflows. This enables the agent to resume execution from where it left off if interrupted.

**Component Configuration (agent-workflow.yaml)**:

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

## 5. Run the Durable Agent

Use the **Terminal** window to create a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Run the durable agent with Dapr by running this command in the **Terminal** window:

```bash,run
dapr run --app-id durable-agent --resources-path resources -- python 02_durable_agent_http.py
```

## 6. Interact with the Durable Agent

Unlike simpler agents, durable agents provide REST APIs for interaction. Here's how to use them:

### Trigger the agent

Run this command in the **cURL** window to start a new workflow and capture the returned instance ID:

```bash,run
INSTANCEID=$(curl -s -X POST http://localhost:8001/agent/run \
  -i \
  -H "Content-Type: application/json" \
  -d '{"task": "What is the weather in London?"}' | \
  grep -o '"instance_id":"[^"]*"' | \
  sed 's/"instance_id":"//;s/"//g' | \
  tr -d '\r\n')
```

This initiates a new workflow for finding flights to Paris. You'll receive a workflow ID in response.

### Check the response in the terminal

The **Terminal** window running the durable agent will show logs similar to this:

```text,nocopy
user:
What is the weather in London?

--------------------------------------------------------------------------------

WeatherAgent(assistant):

Function name: SlowWeatherFunc (Call Id: call_n5Vl1iDuCDIGfrfMqf1qQ5sm)
Arguments: {"location":"London"}


--------------------------------------------------------------------------------

SlowWeatherFunc(tool) (Id: call_n5Vl1iDuCDIGfrfMqf1qQ5sm):
London: 71F.

--------------------------------------------------------------------------------

WeatherAgent(assistant):
The current weather in London is 71°F. If you need more details or forecasts, just let me know!

--------------------------------------------------------------------------------
```

### Check the workflow status

Run this command in the **cURL** window to check the status of the workflow:

```bash,run
curl -i -X GET http://localhost:8001/agent/instances/$INSTANCEID
```

This allows you to track the progress of long-running tasks.

The result should look something like this:

```json,nocopy
{"instance_id":"23a04622820f4f0cb08e73ca97f932ce","name":"dapr.agents.WeatherAgent.workflow","runtime_status":"COMPLETED","created_at":"2026-03-13T09:56:45.406285","last_updated_at":"2026-03-13T09:56:54.836289","serialized_input":"{\"task\": \"What is the weather in London?\"}","serialized_output":"{\"content\": \"The current weather in London is 80\\u00b0F.\", \"role\": \"assistant\", \"name\": \"WeatherAgent\"}","serialized_custom_status":null}
```

> [!IMPORTANT]
> Use `CTRL+C` in the **Terminal** window to stop the DurableAgent application.

## 7. How This Works

1. The agent schedules the prompt as a workflow execution and persists every step to durable storage.
2. The agent creates a workflow activity to perform the LLM interaction and determine whether a tool call is needed.
3. The agent creates another workflow activity to perform the tool call.
4. The agent creates another workflow activity to return the tool call result to the LLM and complete the reasoning step.
5. The agent finishes the execution, persisting every interaction and the final result. The workflow engine ensures reliable progression so no LLM or tool call is repeated unless required.

---

You've now learned about using durable AI agents that can survive failures and maintain state across sessions. Let's move on to the next challenge where you'll use a similar durable agent but it uses pub/sub messaging instead of an HTTP endpoint.