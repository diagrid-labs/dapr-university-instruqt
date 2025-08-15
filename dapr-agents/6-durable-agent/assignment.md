In this challenge, you'll learn how to create durable AI agents that can survive failures and maintain state across sessions using Dapr Agents. You'll explore how the DurableAgent class leverages internally Dapr's Workflow building block to provide persistence, resilience, and stateful behavior.

### Prerequisite

> [!IMPORTANT]
> Open the `.env` file in the current folder and validate the `OPENAI_API_KEY` value is present. If it is not present, update it with your actual OpenAI API key.

## 1.  Why Use DurableAgent?

The DurableAgent is Dapr Agents' most powerful and resilient agent type, designed for production-level AI applications. Unlike the previously explored agent type, the DurableAgent:

1. **Implements the Workflow Pattern**: Uses Dapr's workflow engine to execute tasks in a durable, recoverable manner
2. **Preserves State Across Failures**: Stores all conversation state and execution progress in persistent storage
3. **Manages Complex Tool Interactions**: Orchestrates tool calls with proper error handling and retry logic
4. **Supports Multi-Agent Communication**: Can broadcast messages to other agents and receive responses
5. **Exposes Service APIs**: Provides REST endpoints to trigger workflows and check their status

This makes the DurableAgent ideal for mission-critical applications that need to remain functional even when facing system failures, network issues, or process restarts.

## 2.  Explore the DurableAgent

Use the **Editor** window to examine the durable agent implementation in the `03_durable_agent.py` file:

```python,nocopy
import asyncio
import logging
from typing import List
from pydantic import BaseModel, Field
from dapr_agents import tool, DurableAgent
from dapr_agents.memory import ConversationDaprStateMemory
from dotenv import load_dotenv

# Define tool output model
class FlightOption(BaseModel):
    airline: str = Field(description="Airline name")
    price: float = Field(description="Price in USD")

# Define tool input model
class DestinationSchema(BaseModel):
    destination: str = Field(description="Destination city name")

# Define flight search tool
@tool(args_model=DestinationSchema)
def search_flights(destination: str) -> List[FlightOption]:
    """Search for flights to the specified destination."""
    # Mock flight data (would be an external API call in a real app)
    return [
        FlightOption(airline="SkyHighAir", price=450.00),
        FlightOption(airline="GlobalWings", price=375.50),
    ]

async def main():
    try:
        # Initialize TravelBuddy agent
        travel_planner = DurableAgent(
            name="TravelBuddy",
            role="Travel Planner",
            goal="Help users find flights and remember preferences",
            instructions=[
                "Find flights to destinations",
                "Remember user preferences",
                "Provide clear flight info",
            ],
            tools=[search_flights],
            message_bus_name="messagepubsub",
            state_store_name="workflowstatestore",
            state_key="workflow_state",
            agents_registry_store_name="registrystatestore",
            agents_registry_key="agents_registry",
            memory=ConversationDaprStateMemory(
                store_name="conversationstore", session_id="my-unique-id"
            ),
        )

        travel_planner.as_service(port=8001)
        await travel_planner.start()
        print("Travel Planner Agent is running")

    except Exception as e:
        print(f"Error starting service: {e}")

if __name__ == "__main__":
    load_dotenv()
    logging.basicConfig(level=logging.INFO)
    asyncio.run(main())
```

In contrast to Agent, which does not persist execution state (beyond chat memory), DurableAgent is designed to support durable, coordinated workflows. It enables:

- **Persistent workflow state tracking**
Configured with `state_store_name` and `state_key` to retain execution state across restarts and failures
- **Execution continuation across turns**
Managed with internal state to support multi-step task handling without reprocessing
- **Message-based orchestration**
Uses message_bus_name to integrate with Dapr pub/sub for asynchronous communication between agents and services
- **Agent instance registry**
Configured with `agents_registry_store_name`, which contains agent metadata, and `agents_registry_key`, which contains the agent identifier. This is used to retrieve all available agents and their roles inside agentic workflows
- **Service-mode execution**
Enabled through `as_service(...)` and `start()` to run the agent as a long-lived, REST-accessible background service

## Behind the Scenes: The DurableAgent's Workflow Engine

1. **Manages Workflow State**: Each conversation becomes a workflow instance with its own state
2. **Orchestrates Tool Execution**: Workflows break down complex tasks into steps that can be retried
3. **Handles Failures Gracefully**: If a failure occurs, the workflow can resume from its last checkpoint
4. **Routes Messages**: Uses message routing to communicate between agents and external systems
5. **The workflow engine provides:**
   - **Activity checkpointing**: Each significant operation is persisted before execution
   - **Automatic retry logic**: Failed operations can be retried
   - **Workflow continuity**: Workflows can be continued even after the process restarts

## 3. Key Components of DurableAgent

Let's explore the key components that enable durability in the DurableAgent:

### 1. Persistent Memory

```python,nocopy
memory=ConversationDaprStateMemory(
    store_name="conversationstore",
    session_id="my-unique-id"
)
```

This configures the agent to store its conversation history in a Dapr state store, enabling it to remember context across sessions and survive restarts. The `session_id` ensures that conversations are properly identified and isolated.

### 2. State Stores for Workflow Orchestration

```python,nocopy
state_store_name="workflowstatestore",
state_key="workflow_state",
```

These parameters configure where the agent stores its execution state for workflows. This enables the agent to resume execution from where it left off if interrupted.

**Component Configuration (workflowstatestore.yaml)**:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: workflowstatestore
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

### 3. Agent Registry

```python,nocopy
agents_registry_store_name="registrystatestore",
agents_registry_key="agents_registry",
```

The agent registry stores metadata about available agents, their capabilities, and state. This enables service discovery and coordination in multi-agent systems.

### 4. Message Bus

```python,nocopy
message_bus_name="messagepubsub",
```

The message bus provides reliable asynchronous communication, ensuring messages are not lost even if components fail temporarily.

**Component Configuration (messagepubsub.yaml)**:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: messagepubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
```

### 5. Service Exposure

```python,nocopy
travel_planner.as_service(port=8001)
```

This exposes the agent as a REST service, allowing other systems to interact with it through standard HTTP requests.

## 4. Run the Durable Agent

Use the **Terminal** window to create a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Use the **Terminal** window to navigate to the 01-hello-world folder:

```bash,run
cd 01-hello-world
```

Use the **Terminal** window to install the dependencies:

```bash,run
uv sync --active
```

Run the durable agent with Dapr by running this command in the **Terminal** window:

```bash,run
dapr run --app-id durable-agent --app-port 8001 --dapr-http-port 3500 --resources-path ./components -- python3 03_durable_agent.py
```

This command:

1. Starts Dapr with the specified application ID
2. Configures the port for the REST API
3. Sets the path to the component configurations
4. Launches the agent application

## 5. Interact with the Durable Agent

Unlike simpler agents, durable agents provide REST APIs for interaction. Here's how to use them:

### Start a Workflow

Run this command in the **cURL** window to start a new workflow:

```bash,run
INSTANCEID=$(curl -s -X POST http://localhost:8001/start-workflow \
  -i \
  -H "Content-Type: application/json" \
  -d '{"task": "I want to find flights to Paris"}' | \
  grep -o '"workflow_instance_id":"[^"]*"' | \
  sed 's/"workflow_instance_id":"//;s/"//g' | \
  tr -d '\r\n')
```

This initiates a new workflow for finding flights to Paris. You'll receive a workflow ID in response.

### Check the Workflow Status

Run this command in the **cURL** window to check the status of the workflow:

```bash,run
# Replace WORKFLOW_ID with the ID from the previous response
curl -i -X GET http://localhost:3500/v1.0/workflows/dapr/$INSTANCEID
```

This allows you to track the progress of long-running tasks.

## 6. Benefits of Durable Agents

1. **Resiliency**: Agents can survive process crashes, network issues, and other failures
2. **Stateful Conversations**: Maintain conversation context even across system restarts
3. **Long-Running Tasks**: Handle operations that take significant time to complete
4. **Progress Tracking**: Monitor the status of complex workflows
5. **Automatic Recovery**: Resume from failures without losing progress
6. **Scalability**: Distribute agent workloads across multiple nodes

These capabilities make durable agents ideal for production environments where reliability is essential.

## When to Use Durable Agents

Durable agents are particularly valuable for:

- Mission-critical AI applications that can't afford to lose state
- Long-running conversations that need to persist across sessions
- Complex workflows involving multiple external systems
- Applications that need to survive infrastructure failures
- Systems where progress tracking is important
- Production deployments where reliability is a key requirement

For simple prototypes or quick experiments, simpler agent types might be sufficient, but for production use, durable agents provide the reliability you need.

---

You've now learned about using durable AI agents that can survive failures and maintain state across sessions. Let's move on to the next challenge where you'll use a workflow that chains together multiple AI tasks.