# Making LangGraph agents durable with Dapr Workflow

LangGraph gives an LLM the structure to act as a state machine: nodes, edges, and shared state driving a tool-calling loop. What it doesn't give you is durability. Kill the process mid-run and everything in memory is gone. In this hands-on track you'll see how Dapr Workflow turns a LangGraph graph into a durable, crash-proof application.

## What you'll build

You'll run **Schedule Planner**, a LangGraph agent with a single `check_availability` tool. It's wrapped in `DaprWorkflowGraphRunner` so every node execution becomes a checkpointed Dapr Workflow activity. Then you'll deliberately crash a simpler 3-node version mid-run and watch it resume exactly where it left off.

## What you'll learn

- How LangGraph builds an agent from nodes, edges, and state, and how the tool-calling loop works.
- What `DaprWorkflowGraphRunner` adds on top of a compiled LangGraph graph.
- How to trigger an agentic Dapr Workflow over HTTP and read its output.
- How to inspect checkpointed workflow state directly in Redis.
- How a real process crash resumes from durable state without repeating completed steps.

## Supported language

Python

## Prerequisites

Familiarity with Python is recommended. The sandbox comes preconfigured with Docker, Python, uv, and Dapr. You'll need your own OpenAI API key to run the agent.
