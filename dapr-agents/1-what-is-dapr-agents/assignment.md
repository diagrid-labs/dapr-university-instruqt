## 1. Understanding Dapr Agents

Dapr Agents is a developer framework designed to build resilient AI agent systems that operate at scale. Built on top of the battle-tested Dapr project, it enables software developers to create AI agents that reason, act, and collaborate using Large Language Models (LLMs), while leveraging built-in observability and stateful workflow execution to guarantee agentic workflows complete successfully, no matter how complex.

![Dapr Agents Concept](https://dapr.github.io/dapr-agents/img/concepts-agents.png)

Dapr Agents provides a structured way to build, deploy, and orchestrate applications that use LLMs like OpenAI's GPT models, without getting bogged down in implementation details. The primary goal is to make AI development more accessible by abstracting away the complexities of working with LLMs, tools, memory management, and distributed systems, allowing developers to focus on the business logic of their AI applications.

## 2. Key Concepts

### LLM Integration

Dapr Agents provides a unified interface to connect with LLM inference APIs. This abstraction allows developers to seamlessly integrate their agents with cutting-edge language models for reasoning and decision-making, without being locked into a specific provider.

Agents in Dapr Agents leverage structured output capabilities, such as OpenAI's Function Calling, to generate predictable and reliable results. These outputs follow JSON Schema and OpenAPI Specification standards, enabling easy interoperability and tool integration.

The framework includes multiple LLM clients for different providers and modalities:

- **OpenAIChatClient**: Full spectrum support for OpenAI (and OpenAI compatible REST APIs such as the one offered through Azure) models including chat, embeddings, and audio
- **HFHubChatClient**: For Hugging Face models supporting both chat and embeddings
- **NVIDIAChatClient**: For NVIDIA AI Foundation models supporting local inference and chat
- **ElevenLabs**: Support for speech and voice capabilities
- **DaprChatClient**: Unified API for LLM interactions via Dapr's Conversation API with built-in security (scopes, secrets, PII obfuscation), resiliency (timeouts, retries, circuit breakers), and observability via OpenTelemetry & Prometheus

### Memory

Agents retain context across interactions, enhancing their ability to provide coherent and adaptive responses. Memory options range from simple in-memory lists for managing chat history to vector databases for semantic search and retrieval. Dapr Agents also integrates with all available [Dapr state stores](https://docs.dapr.io/operations/components/setup-state-store/), enabling scalable and persistent memory for advanced use cases. These state stores can be used interchangeably as chat memory and easily swapped out as needed.

### Tools and MCP Integration

Agents dynamically select the appropriate tool for a given task, using LLMs to analyze requirements and choose the best action. This is supported directly through LLM parametric knowledge and enhanced by Function Calling, ensuring tools are invoked efficiently and accurately.

Dapr Agents includes built-in support for the Model Context Protocol (MCP), enabling agents to dynamically discover and invoke external tools through a standardized interface. This allows agents to incorporate capabilities exposed by external processes without hardcoding or preloading them.

### Agents

An agent is a  self-contained execution unit that can think, plan, and act on its own, using tools and collaborating with other agents to achieve defined objectives. Dapr Agents offers the following types of agents:

- **Agent**: Stateless agent that manages conversation and executes tools based on LLM-generated tool calls. Best for lightweight, reactive tasks requiring direct tool invocation.
- **DurableAgent**: Workflow-native agent for coordinating multi-turn conversations and tool execution. Designed for stateful, resilient, and routable agent workflows with built-in durability.

### Workflows for Agentic Orchestration

Dapr Agents supports both deterministic and event-driven workflows to manage multi-agent systems. Deterministic workflows provide clear, repeatable processes, while event-driven workflows allow for dynamic, adaptive collaboration between agents. Agents collaborate through Pub/Sub messaging, enabling event-driven communication and task distribution. This message-driven architecture allows agents to work asynchronously, share updates, and respond to real-time events, ensuring effective collaboration in distributed systems.

## 3. Benefits of Using Dapr Agents

### Agent-Centric Model

- **LLM-Powered Intelligence**: Leverage LLMs for reasoning, dynamic decision-making, and natural language interactions
- **Complete API Surface**: Provides a comprehensive toolkit to address common AI problems with support for tool calling and reasoning loops (e.g., ReAct)

### Actor-Based Architecture

- **Stateful & Efficient**: Agents process one task at a time, avoiding concurrency issues while maintaining state
- **Cost-Effective Scaling**: Reliably runs thousands of agents on a single core with the ability to scale to zero when idle

### Workflow-Oriented Design

- **Execution Guarantees**: Ensures each agent task is completed successfully despite failures or interruptions
- **Versatile Interactions**: Supports both deterministic workflows and event-driven, message-based communication
- **Business-Critical Operations**: Built for durable, long-running processes on top of the actor model

### Decoupled Infrastructure

- **Clean Separation**: Agents operate independently from the underlying infrastructure components
- **Simplified Integrations**: Built-in connectivity to enterprise data sources
- **Technology Flexibility**: Easily switch between databases (Postgres, MySQL, AWS DynamoDB) or message brokers (Kafka, MQTT)

### Enterprise-Ready & Vendor-Neutral

- **Built on Dapr**: Leverages a trusted enterprise framework with observability, security, and resiliency at scale
- **CNCF Foundation**: Part of the Cloud Native Computing Foundation ecosystem, eliminating vendor lock-in risks

## 4. How Dapr Agents Relates to Dapr

Dapr Agents is built on top of Dapr, leveraging its distributed application capabilities:

- **Dapr Building Blocks**: Dapr provides core infrastructure patterns like state management, pub/sub messaging, service invocation, and virtual actors.
- **Dapr PubSub**: Enables event-driven communication between agents, facilitating multi-agent coordination and collaboration in distributed systems.
- **Workflows**: Dapr Agents uses Dapr's Workflow API for orchestrating complex multi-step agentic workflows.
- **Dapr Conversation API**: Provides a unified interface for LLM interactions with built-in security, resiliency, and observability features.
- **LLM-Specific Extensions**: Dapr Agents adds LLM capabilities including prompt templating, schema-based structured outputs, and memory management for consistent, predictable agent interactions.

Together, they create a powerful duo for building distributed, scalable, and resilient AI applications.

---

You now know that Dapr Agents is a developer framework designed to build resilient AI agent systems that operate at scale and is built on open source Dapr. Let's continue and take a look at a basic LLM call via Dapr Agents.
