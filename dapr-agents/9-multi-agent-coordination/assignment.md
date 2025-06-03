In this tutorial, you'll learn how to create and orchestrate event-driven workflows with multiple autonomous agents using Dapr Agents. You'll explore how agents can collaborate to solve complex problems through pub/sub messaging and different orchestration strategies.

### Prerequisite

> [!IMPORTANT]
> Open the `.env` file in the current folder and validate the `OPENAI_API_KEY` value is present. If it is not present, update with your actual OpenAI API key.

## Understanding Multi-Agent Systems

Multi-agent systems consist of multiple specialized AI agents that collaborate to solve complex tasks that might be difficult for a single agent to handle. Key characteristics include:

1. **Specialized Agents**: Each agent has a specific role, personality, and set of skills
2. **Event-Driven Communication**: Agents communicate via messages through a pub/sub system
3. **Orchestration**: A coordinator manages the flow of information between agents
4. **Stateful Interactions**: The system maintains state across the conversation

This approach enables powerful collaborative problem-solving, parallel processing, and division of responsibilities among specialized agents.

## Exploring Agent Specialization

In a multi-agent system, each agent is specialized for a particular role. Let's examine how agents with different specializations are defined:

```python,nocopy
from dapr_agents import AssistantAgent
from dotenv import load_dotenv
import asyncio
import logging

async def main():
    try:
        hobbit_service = AssistantAgent(
          name="Frodo",
          role="Hobbit",
          goal="Carry the One Ring to Mount Doom, resisting its corruptive power while navigating danger and uncertainty.",
          instructions=[
              "Speak like Frodo, with humility, determination, and a growing sense of resolve.",
              "Endure hardships and temptations, staying true to the mission even when faced with doubt.",
              "Seek guidance and trust allies, but bear the ultimate burden alone when necessary.",
              "Move carefully through enemy-infested lands, avoiding unnecessary risks.",
              "Respond concisely, accurately, and relevantly, ensuring clarity and strict alignment with the task."],
          message_bus_name="messagepubsub",
          state_store_name="workflowstatestore",
          state_key="workflow_state",
          agents_registry_store_name="agentstatestore",
          agents_registry_key="agents_registry", 
        )

        await hobbit_service.start()
    except Exception as e:
        print(f"Error starting service: {e}")
```

In this example, we're creating a "Frodo" agent with specific personality traits, goals, and instructions that shape its behavior. Similar agents can be created for other roles, like "Gandalf" (the wizard) or "Legolas" (the elf), each with their own unique characteristics.

## Orchestration Strategies

A crucial component of multi-agent systems is the orchestrator that coordinates interactions between agents. Dapr Agents supports three orchestration strategies:

### 1. Random Orchestrator

The Random orchestrator selects agents randomly to respond to queries:

```python,nocopy
from dapr_agents import RandomOrchestrator
from dotenv import load_dotenv
import asyncio
import logging

async def main():
    try:
        random_workflow_service = RandomOrchestrator(
            name="RandomOrchestrator",
            message_bus_name="messagepubsub",
            state_store_name="agenticworkflowstate",
            state_key="workflow_state",
            agents_registry_store_name="agentstatestore",
            agents_registry_key="agents_registry",
            max_iterations=3
        ).as_service(port=8004)
        await random_workflow_service.start()
    except Exception as e:
        print(f"Error starting service: {e}")
```

This approach is useful for:

- Load balancing across agents
- Creating more diverse conversations
- Testing and debugging multi-agent interactions

### 2. RoundRobin Orchestrator

The RoundRobin orchestrator cycles through agents in a predetermined sequence:

```python,nocopy
from dapr_agents import RoundRobinOrchestrator
# Similar configuration as the RandomOrchestrator
```

This approach ensures:
- Equal participation from all agents
- Predictable turn-taking behavior
- Fair distribution of tasks

### 3. LLM-Based Orchestrator

The LLM-based orchestrator uses an LLM to intelligently select the most appropriate agent for each query:

```python,nocopy
from dapr_agents import LLMOrchestrator
# Similar configuration as the RandomOrchestrator
```

This approach provides:
- Context-aware agent selection
- Dynamic adaptation to conversation flow
- More natural multi-agent interactions

## Event-Driven Communication

Agents in a multi-agent system communicate with each other through an event-driven pub/sub system. This allows for:

1. **Asynchronous Communication**: Agents can send and receive messages without blocking
2. **Decoupled Architecture**: Agents don't need to know about each other directly
3. **Scalable Interactions**: The system can easily scale to many agents
4. **Reliable Message Delivery**: Messages are guaranteed to be delivered

The communication is configured through Dapr's pub/sub component, which can use various backends (Redis, Kafka, RabbitMQ, etc.) for message delivery.

## Running a Multi-Agent System

To run a complete multi-agent system with Dapr, we use a multi-app run configuration. Here's an example from `dapr-llm.yaml`:

```yaml,nocopy
version: 1
common:
  resourcesPath: ./components
  logLevel: info
  appLogDestination: console
  daprdLogDestination: console

apps:
- appID: HobbitApp
  appDirPath: ./services/hobbit/
  command: ["python3", "app.py"]

- appID: WizardApp
  appDirPath: ./services/wizard/
  command: ["python3", "app.py"]

- appID: ElfApp
  appDirPath: ./services/elf/
  command: ["python3", "app.py"]

- appID: WorkflowApp
  appDirPath: ./services/workflow-llm/
  command: ["python3", "app.py"]
  appPort: 8004

- appID: ClientApp
  appDirPath: ./services/client/
  command: ["python3", "http_client.py"]
```

To use this configuration, run the following command in the **Terminal** window:

```bash
dapr run -f dapr-llm.yaml
```

This will start all the agents, the orchestrator, and a client application for interacting with the system. The agents will then collaborate to respond to user queries.

## How Multi-Agent Collaboration Works

Let's explore how the collaboration works in a typical multi-agent interaction:

1. **Client Submits a Query**: "How to get to Mordor? We all need to help!"
2. **Orchestrator Receives the Query**: The orchestrator (Random, RoundRobin, or LLM-based) receives the query
3. **Agent Selection**: The orchestrator selects an agent to respond (based on its strategy)
4. **Agent Processes the Query**: The selected agent generates a response
5. **Response Publication**: The agent publishes its response to the pub/sub system
6. **Orchestrator Evaluates**: The orchestrator decides if more agent input is needed
7. **Additional Agent Selection**: If needed, another agent is selected to contribute
8. **Response Aggregation**: The contributions are collected into a coherent conversation
9. **Client Receives Response**: The final response is sent back to the client

This cycle can continue for multiple iterations until the task is complete or a maximum number of iterations is reached.

## Multi-Agent System Components

A complete multi-agent system includes several key components:

### 1. Agent Services

Each agent runs as an independent service with its own lifecycle. This enables:

- Independent scaling of agents based on demand
- Resilience through service isolation
- Clear separation of responsibilities

### 2. Pub/Sub Messaging

The pub/sub component facilitates message exchange between agents:

- Topics for different types of messages
- Subscriptions for specific message types
- Message persistence for reliability

### 3. State Stores

Multiple state stores maintain different types of state:

- Conversation state for ongoing interactions
- Agent registry for discovering available agents
- Workflow state for orchestration progress

### 4. Client Interface

A client application or API provides an interface for users to interact with the multi-agent system

- Submitting queries
- Receiving responses
- Monitoring conversation progress

## When to Use Multi-Agent Systems

Multi-agent systems are particularly well-suited for:

- **Complex Problem Solving**: Tasks requiring multiple types of expertise
- **Creative Collaboration**: Generating ideas from diverse perspectives
- **Role-Playing Scenarios**: Simulating interactions between different characters
- **Debate and Deliberation**: Presenting multiple viewpoints on a topic
- **Distributed Processing**: Breaking down large tasks into parallel operations

By leveraging multiple specialized agents, you can create AI systems that tackle problems too complex for a single agent to handle effectively.
