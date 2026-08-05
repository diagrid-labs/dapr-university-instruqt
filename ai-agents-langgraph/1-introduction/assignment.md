Welcome to **Making LangGraph Agents Durable with Dapr Workflow**. In this track you'll run a LangGraph agent, a **Schedule Planner** that checks venue availability. Then you'll make it durable enough to survive a crash. This first challenge takes about 4 minutes.

## What is LangGraph?

[LangGraph](https://www.langchain.com/langgraph) is a framework for building agents as **state machines**. Instead of a single prompt-and-response loop, you define:

- **Nodes**: plain functions that read and write a shared state.
- **Edges**: the paths between nodes, including conditional edges that route based on the state (for example, "call a tool" versus "stop").
- **State**: a shared dictionary that flows through the graph as it executes.

A plain LLM loop calls the model once and returns. A LangGraph agent can loop. It calls the model, decides whether to call a tool, calls it, feeds the result back to the model, and repeats until the model is done. That loop is what you'll inspect in the next challenge.

## Why durability matters

A LangGraph graph runs entirely in process memory by default. Every node execution, every tool result, and every message in the conversation lives in a Python variable. Kill the process mid-loop and it's all gone. You'd have to start the whole run over, including any LLM calls you already paid for.

LangGraph gives you the structure for an agent. It doesn't give you durability. That's what **Dapr Workflow** adds. Wrap the same compiled graph in a `DaprWorkflowGraphRunner` and every node execution becomes a checkpointed Dapr Workflow activity, persisted to Redis before the graph moves to the next step. In challenges 3 and 4 you'll run that durable version and prove it survives a real crash.

## What you'll build

You'll run **Schedule Planner**, a LangGraph agent with a single tool called `check_availability` that checks whether a venue is free on a given date. The agent is wrapped in a Dapr Workflow and exposed over HTTP. A `POST` to `/agent/run` triggers a run, the LLM decides to call `check_availability`, and the agent returns the available time slots.

## 1. Verify the sandbox

Use the **Terminal** window to confirm the Dapr CLI and runtime are ready:

```bash,run
dapr -v
```

> [!NOTE]
> You should see both a **CLI version** and a **Runtime version** listed. If the Runtime version is blank, run `dapr init` below to initialize it. If you run into any other blocking issue during this course, send me [an email](mailto:marc@diagrid.io) and we'll figure it out together.

```bash,run
dapr init
```

## 2. Add your OpenAI API key

`main.py` reads `OPENAI_API_KEY` straight from the shell environment. There's no `.env` file involved. So that the key is available in every terminal tab across the rest of this track, not just the one you're in right now, append it to `~/.bashrc`:

```bash,run,copy
echo 'export OPENAI_API_KEY="your_key_here"' >> ~/.bashrc
source ~/.bashrc
```

> [!NOTE]
> You'll need a real key from https://platform.openai.com/signup. The agent calls `gpt-4.1` in challenge 3. Replace `your_key_here` with your actual key before running the command above.

---

You now have a working sandbox and know why a durability layer is worth adding to a LangGraph agent. Let's move on to challenge 2 where you'll read through the Schedule Planner's graph.
