In this final challenge, you'll learn how to create multi-agent systems that communicate using event-driven workflows with Dapr Agents. You'll explore how agents can collaborate to solve complex problems through pub/sub messaging and different orchestration strategies.

### Prerequisite

> [!IMPORTANT]
> Open the `.env` file in the current folder and validate the `OPENAI_API_KEY` value is present. If it is not present, update it with your actual OpenAI API key.

## 1. Understanding Multi-Agent Systems

Multi-agent systems consist of multiple specialized AI agents that collaborate to solve complex tasks that might be difficult for a single agent to handle. Key characteristics of such a system in Dapr Agents include:

1. **Specialized Agents**: Each agent has a specific role, personality, and set of skills
2. **Event-Driven Communication**: Agents communicate via messages through a pub/sub system
3. **Orchestration**: A coordinator manages the flow of information between agents
4. **Stateful Interactions**: The system maintains state across the conversation

This approach enables powerful collaborative problem-solving, parallel processing, and division of responsibilities among specialized agents.

### Core Participants

To implement such a collaborative system, requires the following key participants that work together:

#### Agent Services

Each agent runs as an independent service with its own lifecycle. This enables:

- Independent scaling of agents based on demand
- Resilience through service isolation
- Clear separation of responsibilities

#### Orchestrator

The orchestrator coordinates interactions between agents and manages the flow of the conversation:

- Selects which agent should respond to queries
- Manages the sequence of agent interactions
- Tracks conversation progress and completion
- Implements different coordination strategies (Random, RoundRobin, LLM-based)

#### Client Application

A client application or API provides an interface for users to interact with the multi-agent system:

- Submitting queries
- Receiving responses
- Monitoring conversation progress

#### Backing Infrastructure

The underlying infrastructure components that enable reliable communication and state management:

- **Pub/Sub Messaging**: Facilitates message exchange between agents with topics for different message types, subscriptions for specific message types, and message persistence for reliability.

- **State Stores**: Multiple state stores maintain different types of state including conversation state for ongoing interactions, agent registry for discovering available agents, and workflow state for orchestration progress.

These participants work together to create a robust, scalable foundation for multi-agent collaboration, ensuring that agents can communicate effectively while maintaining their independence and specialization.

## 2. Exploring Agent Specialization

In a multi-agent system, each agent is specialized for a particular role. Each agent has its own service implementation that defines its unique characteristics, personality, and capabilities.
Use the **Editor** window to examine the Hobbit agent implementation in the `services/hobbit/app.py` file:

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

You'll notice how the "Frodo" agent is defined with specific personality traits, goals, and instructions that shape its behavior. The agent is configured with:

- A clear role and name
- A specific goal that drives its actions
- Detailed instructions that define its personality and response style
- Integration with the message bus and state stores for collaboration

Next, use the **Editor** window to explore the wizard agent in the `services/wizard/app.py` file:

Compare how "Gandalf" differs from "Frodo" - you'll see different goals, instructions, and personality traits that make this agent behave as a wise advisor rather than a determined ring-bearer.

Finally, examine the elf agent implementation in the `services/elf/app.py` file:
Notice how "Legolas" has yet another distinct personality and set of capabilities, emphasizing keen observation, precision, and scouting abilities.

Each agent follows the same structural pattern but with unique characteristics that make them suitable for different aspects of problem-solving. This specialization allows the multi-agent system to tackle complex tasks by leveraging the diverse strengths of each participant.

## 3. Orchestration Strategies

A crucial component of multi-agent systems is the orchestrator that coordinates interactions between agents. Dapr Agents supports three orchestration strategies:

### Random Orchestrator

The Random orchestrator selects agents randomly to respond to queries. Open the `services/workflow-random/app.py` file in the **Editor** window to see how it is implemented.

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

### RoundRobin Orchestrator

The RoundRobin orchestrator cycles through agents in a predetermined sequence. Open the `services/workflow-roundrobin/app.py` file in the **Editor** window to see how it is implemented.

```python,nocopy
from dapr_agents import RoundRobinOrchestrator
# Similar configuration as the RandomOrchestrator
```

This approach ensures:

- Equal participation from all agents
- Predictable turn-taking behavior
- Fair distribution of tasks

### LLM-Based Orchestrator

The LLM-based orchestrator uses an LLM to intelligently select the most appropriate agent for each query. Open the `services/workflow-llm/app.py` file in the **Editor** window to see how it is implemented.

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

## 4. Client Application

The client application serves as the entry point for users to interact with the multi-agent system. It handles user input and initiates conversations with the orchestrator.

Use the **Editor** window to examine the HTTP client implementation in the `services/client/http_client.py` file. This client demonstrates how to interact with the multi-agent system through HTTP requests. It sends queries to the orchestrator and receives responses from the collaborative agent system.

Next, explore the pub/sub client in the `services/client/pubsub_client.py` file. This alternative client shows how to interact with the system through message publishing, demonstrating the event-driven communication approach where the client publishes messages to trigger agent workflows.

## 5. Run a Multi-Agent System

The Dapr CLI provides a [multi-app run](https://docs.dapr.io/developing-applications/local-development/multi-app-dapr-run/multi-app-overview/) feature that allows you to start multiple applications with their Dapr sidecars using a single command. This is essential for running multi-agent systems where several services need to work together.

This example includes three multi-app run configurations that are nearly identical, with the only difference being which orchestrator they use.

Use the **Editor** window to examine the `dapr-llm.yaml` configuration file:

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

This configuration runs all the participants we discussed earlier:

- **Agent Services**: Three specialized agents (Hobbit, Wizard, Elf) that handle different aspects of problem-solving
- **Orchestrator**: The workflow service that coordinates agent interactions (in this case, the LLM-based orchestrator)
- **Client Application**: The HTTP client that allows users to submit queries and receive responses

Each service runs independently with its own Dapr sidecar, enabling them to communicate through the pub/sub messaging system and maintain state through the configured state stores.

### Run the multi-app run configuration

Use the **Terminal** window to create a virtual environment:

```bash,run
python3 -m venv .venv
source .venv/bin/activate
```

Use the **Terminal** window to install the dependencies:

```bash,run
pip install -r requirements.txt
```

To use this configuration, run the following command in the **Terminal** window:

```bash,run
dapr run -f dapr-llm.yaml
```

This will start all the agents, the orchestrator, and a client application for interacting with the system. The agents will then collaborate to respond to user queries. It will take some time before the orchestrator is completed.

You should see output similar to:

```text,nocopy
== APP - WorkflowApp == 2025-06-06 10:29:14.529 durabletask-client INFO: Instance '72a0b889f5284c848c36f463e3af3ad1' completed.
== APP - WorkflowApp == INFO:dapr_agents.workflow.base:Workflow 72a0b889f5284c848c36f463e3af3ad1 completed with status: WorkflowStatus.COMPLETED.
== APP - WorkflowApp == INFO:dapr_agents.workflow.base:Workflow '72a0b889f5284c848c36f463e3af3ad1' completed successfully. Status: COMPLETED.
== APP - WorkflowApp == INFO:dapr_agents.workflow.base:Finished monitoring workflow '72a0b889f5284c848c36f463e3af3ad1'.
```

You can now stop the multi-app run by pressing `Ctrl+C` in the **Terminal** window.

### Inspect the output of the LLM-based orchestator

The LLM-based orchestrator has saved the output in a file named `LLMOrchestrator_state.json` located in the `services/workflow-llm/` folder.

> [!Note]
> Since this json file is generated by the orchestrator, it will not be visible in the **Editor** window tree view until you have refreshed the tree view using the circular arrow icon.

Use the **Editor** window to open the `services/workflow-llm/LLMOrchestrator_state.json` file and inspect its content. The file contains an `instances` element with different instance ID values, each containing `input` and `output` values, `messages`, and a `plan` with steps and sub steps with a status.

> [!NOTE]
> The LLM-based orchestrator makes many calls to OpenAI and could result in rate limiting your access to the OpenAI API.

## 6. How Multi-Agent Collaboration Works

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

## When to Use Multi-Agent Systems

Multi-agent systems are particularly well-suited for:

- **Complex Problem Solving**: Tasks requiring multiple types of expertise
- **Creative Collaboration**: Generating ideas from diverse perspectives
- **Role-Playing Scenarios**: Simulating interactions between different characters
- **Debate and Deliberation**: Presenting multiple viewpoints on a topic
- **Distributed Processing**: Breaking down large tasks into parallel operations

By leveraging multiple specialized agents, you can create AI systems that tackle problems too complex for a single agent to handle effectively.

## Feedback & Discord

Congratulations! 🎉 You've completed the Dapr University Dapr Agents learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving this training 🚀.

All code samples shown in this Dapr University track are available in the [Dapr Agents](https://github.com/dapr/dapr-agents/) repository in the `quickstarts` folder. Give this repo a star and clone it locally to use it as reference material for building your next workflow project.

If you have any questions or feedback about this track, you can let us know in the *#dapr-agents* channel of the [Dapr Discord server](https://bit.ly/dapr-discord).