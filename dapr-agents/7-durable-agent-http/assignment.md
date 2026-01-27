This challenge turns the previous agent into a durable agent backed by the Dapr Workflow engine. Instead of running interactions in-process, every step of the agent’s execution is persisted to durable storage, allowing long-running interactions to survive interruptions. The agent exposes an HTTP endpoint to start a new workflow and provides a way to query progress or retrieve the final result at any time.

## 1. Durable Agent with REST endpoint

The Durable Agent is Dapr Agents' most powerful and resilient agent type, designed for production-level AI applications. Unlike the previously explored agent type, the Durable Agent:

1. **Implements the Workflow Pattern**: Uses Dapr's workflow engine to execute tasks in a durable, recoverable manner
2. **Preserves State Across Failures**: Stores all conversation state and execution progress in persistent storage
3. **Manages Complex Tool Interactions**: Orchestrates tool calls with proper error handling and retry logic
4. **Supports Multi-Agent Communication**: Can broadcast messages to other agents and receive responses
5. **Exposes Service APIs**: Provides REST endpoints to trigger workflows and check their status

This makes the DurableAgent ideal for mission-critical applications that need to remain functional even when facing system failures, network issues, or process restarts.

## 2. Explore the DurableAgent

Use the **Editor** window to examine the durable agent implementation in the `06_durable_agent_http.py` file.

The agent exposes a REST endpoint, accepts a prompt, and returns a workflow ID that represents a durable execution. You can query this workflow at any time—even after stopping and restarting the agent—and it will resume exactly where it left off. The agent performs an LLM call and a tool call as part of completing the workflow and produces a final result.

### How it works

1. The agent schedules the prompt as a workflow execution and persists every step to durable storage.
2. The agent creates a workflow activity to perform the LLM interaction and determine whether a tool call is needed.
3. The agent creates another workflow activity to perform the tool call.
4. The agent creates another workflow activity to return the tool call result to the LLM and complete the reasoning step.
5. The agent finishes the execution, persisting every interaction and the final result. The workflow engine ensures reliable progression so no LLM or tool call is repeated unless required.

## 3. Behind the Scenes: The DurableAgent's Workflow Engine

1. **Manages Workflow State**: Each conversation becomes a workflow instance with its own state
2. **Orchestrates Tool Execution**: Workflows break down complex tasks into steps that can be retried
3. **Handles Failures Gracefully**: If a failure occurs, the workflow can resume from its last checkpoint
4. **Routes Messages**: Uses message routing to communicate between agents and external systems
5. **The workflow engine provides:**
   - **Activity checkpointing**: Each significant operation is persisted before execution
   - **Automatic retry logic**: Failed operations can be retried
   - **Workflow continuity**: Workflows can be continued even after the process restarts

## 4. Key Components of DurableAgent

Let's explore the key components that enable durability in the DurableAgent:

### Persistent Memory

```python,nocopy
memory=AgentMemoryConfig(
  store=ConversationDaprStateMemory(
    store_name="conversation-statestore",
    session_id=Path(__file__).stem,
  )
)
```

This configures the agent to store its conversation history in a Dapr state store, enabling it to remember context across sessions and survive restarts.

**Component Configuration (conversation-statestore.yaml)**:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: conversation-statestore
spec:
  type: state.redis
  version: v1
  metadata:
    - name: redisHost
      value: localhost:6379
    - name: redisPassword
      value: ""
```

### State Stores for Workflow Orchestration

```python,nocopy
state=AgentStateConfig(
  store=StateStoreService(store_name="workflow-statestore"),
```

These parameters configure where the agent stores its execution state for workflows. This enables the agent to resume execution from where it left off if interrupted.

**Component Configuration (workflow-statestore.yaml)**:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: workflow-statestore
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
dapr run --app-id durable-agent --resources-path resources --app-port 8001 -- python 06_durable_agent_http.py
```

## 6. Interact with the Durable Agent

Unlike simpler agents, durable agents provide REST APIs for interaction. Here's how to use them:

### Trigger the agent

Run this command in the **cURL** window to start a new workflow and capture the returned instance ID:

```bash,run
INSTANCEID=$(curl -s -X POST http://localhost:8001/run \
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
== APP == user:
== APP == What is the weather in London?
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == Function name: SlowWeatherFunc (Call Id: call_5JUSP5K20O2qJ2iwLhUsZKZV)
== APP == Arguments: {"location":"London"}
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == SlowWeatherFunc(tool) (Id: call_5JUSP5K20O2qJ2iwLhUsZKZV):
== APP == London: 62F.
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == The weather in London is currently 62°F. If you need more details, let me know!
== APP == 
== APP == --------------------------------------------------------------------------------
```

### Check the workflow status

Run this command in the **cURL** window to check the status of the workflow:

```bash,run
curl -i -X GET http://localhost:8001/run/$INSTANCEID
```

This allows you to track the progress of long-running tasks.

## 7. Benefits of Durable Agents

1. **Resiliency**: Agents can survive process crashes, network issues, and other failures
2. **Stateful Conversations**: Maintain conversation context even across system restarts
3. **Long-Running Tasks**: Handle operations that take significant time to complete
4. **Progress Tracking**: Monitor the status of complex workflows
5. **Automatic Recovery**: Resume from failures without losing progress
6. **Scalability**: Distribute agent workloads across multiple nodes

These capabilities make durable agents ideal for production environments where reliability is essential.

## 8. When to Use Durable Agents

Durable agents are particularly valuable for:

- Mission-critical AI applications that can't afford to lose state
- Long-running conversations that need to persist across sessions
- Complex workflows involving multiple external systems
- Applications that need to survive infrastructure failures
- Systems where progress tracking is important
- Production deployments where reliability is a key requirement

---

You've now learned about using durable AI agents that can survive failures and maintain state across sessions. Let's move on to the next challenge where you'll use a similar durable agent but it uses pub/sub messaging instead of an HTTP endpoint.