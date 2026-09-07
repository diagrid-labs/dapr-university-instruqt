Welcome to **Making LangGraph Agents Durable with Dapr Workflow - Schedule Planner**. In this track you'll run a LangGraph agent, a **Schedule Planner** that checks venue availability. Then you'll test the durability by making it crash and see it recover on the next run. This first challenge takes about 3 minutes.

## What is LangGraph?

[LangGraph](https://www.langchain.com/langgraph) is a framework for building agents as **state machines**. Instead of a single prompt-and-response loop, you define:

- **Nodes**: plain functions that read and write a shared state.
- **Edges**: the paths between nodes, including conditional edges that route based on the state (for example, "call a tool" versus "stop").
- **State**: a shared dictionary that flows through the graph as it executes.

A plain LLM loop calls the model once and returns. A LangGraph agent can loop. It calls the model, decides whether to call a tool, calls it, feeds the result back to the model, and repeats until the model is done. That loop is what you'll inspect in the next challenge.

## Why durability matters

A LangGraph graph runs entirely in process memory by default. Every node execution, every tool result, and every message in the conversation lives in a Python variable. Kill the process mid-loop and it's all gone. You'd have to start the whole run over, including any model calls you already paid for.

LangGraph gives you the structure for an agent. It doesn't give you durability. That's what **Dapr Workflow** adds. Wrap the same compiled graph in a `DaprWorkflowGraphRunner` and every node execution becomes a checkpointed Dapr Workflow activity, persisted to Redis before the graph moves to the next step. In challenges 3 and 4 you'll run that durable version and prove it survives a real crash.

## What you'll run

You'll run **Schedule Planner**, a LangGraph agent with a single tool called `check_availability` that checks whether a venue is free on a given date. The agent is wrapped in a Dapr Workflow and exposed over HTTP. A `POST` to `/agent/run` triggers a run, the model decides to call `check_availability`, and the agent returns the available time slots. The agent ships with a canned offline model, so this track needs no API key and every run returns the same answer.

## 1. Verify the sandbox

Use the **Terminal** window to confirm the Dapr CLI and runtime are ready:

```bash,run,copy
dapr -v
```

> [!NOTE]
> You should see both a **CLI version** and a **Runtime version** listed. If the Runtime version is blank, run `dapr init` in the **Terminal** to initialize it. If you run into any other blocking issue during this course, send me [an email](mailto:marc@diagrid.io) and we'll figure it out together.

## 2. The model this agent uses

The Schedule Planner ships with a **canned offline model**. It needs no API key, costs nothing, and returns the same tool call and the same answer on every run. That is deliberate: this track is about durable execution, and a deterministic model means a crash and its recovery look identical every time you run them.

You'll read the code that picks the model in the next challenge.

---

You now have a working sandbox and know why a durability layer is worth adding to a LangGraph agent. Let's move on to challenge 2 where you'll read through the Schedule Planner's graph.

> [!IMPORTANT]
> Click the *Check* button to verify that the Dapr containers are running.
