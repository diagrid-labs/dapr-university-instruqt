LangGraph's whole point is the graph, so before running anything, let's read one. This challenge is Editor-only. No terminal, no running. This challenge takes about 4 minutes.

## 1. Open main.py

Open `main.py` in the **Editor**. At a high level, this file builds a LangGraph graph, wraps it in a Dapr Workflow runner, and serves it over HTTP. Let's walk through it top to bottom.

## 2. Inspect the tool

Look at lines 13-16:

```python,nocopy
@tool
def check_availability(venue: str, date: str) -> str:
    """Check venue availability for a specific date."""
    return f"{venue} is available on {date}. Time slots: 9AM-1PM, 2PM-6PM, 6PM-11PM."
```

A LangGraph tool is just a Python function decorated with `@tool`. The LLM never calls this function directly. It decides *when* to call it and *with what arguments*, and LangGraph runs it on the LLM's behalf.

## 3. Inspect the nodes

Look at lines 24-35. There are two functions here, each a **node** in the graph:

```python,nocopy
def call_model(state: MessagesState) -> dict:
    response = model.invoke(state["messages"])
    return {"messages": [response]}


def call_tools(state: MessagesState) -> dict:
    last_message = state["messages"][-1]
    results = []
    for tc in last_message.tool_calls:
        result = tools_by_name[tc["name"]].invoke(tc["args"])
        results.append(ToolMessage(content=str(result), tool_call_id=tc["id"]))
    return {"messages": results}
```

`call_model` sends the conversation so far to the LLM. `call_tools` executes whatever tool calls the LLM asked for. Each is a plain function that reads the shared `MessagesState` and returns updates to it. That's all a LangGraph node is.

## 4. Inspect the routing

Look at lines 38-42:

```python,nocopy
def should_use_tools(state: MessagesState) -> str:
    last_message = state["messages"][-1]
    if hasattr(last_message, "tool_calls") and last_message.tool_calls:
        return "tools"
    return "__end__"
```

`should_use_tools` decides where to go after `call_model` runs. It goes back to `tools` if the LLM asked for a tool call, or ends the graph if it didn't. This is the **conditional edge** that creates the tool-calling loop. Without it, the graph would only ever run once.

## 5. Inspect the graph construction

Look at lines 45-50:

```python,nocopy
graph = StateGraph(MessagesState)
graph.add_node("agent", call_model)
graph.add_node("tools", call_tools)
graph.add_edge(START, "agent")
graph.add_conditional_edges("agent", should_use_tools)
graph.add_edge("tools", "agent")
```

Nodes are registered, then edges are wired: `START → agent → (conditional) → tools → agent → …`. The graph keeps looping between `agent` and `tools` until `should_use_tools` returns `__end__`.

## 6. Inspect the runner

Look at lines 52-66:

```python,nocopy
runner = DaprWorkflowGraphRunner(
    graph=graph.compile(),
    name="schedule-planner",
    role="Schedule Planner",
    goal="Check venue date and time availability using the check_availability tool. Provide available time slots for a given venue and date.",
)

runner.serve(
    port=int(os.environ.get("APP_PORT", "8005")),
    input_mapper=lambda req: {"messages": [HumanMessage(content=req["task"])]},
    pubsub_name="agent-pubsub",
    subscribe_topic="schedule.requests",
    publish_topic="schedule.results",
)
```

`DaprWorkflowGraphRunner(...)` wraps the compiled graph. That one line is the entire durability layer, and you'll see what it actually does in challenge 3. `runner.serve(...)` starts an HTTP server on port `8005` and subscribes to a pub/sub topic, so the same graph can be triggered either way.

## 7. How this works

Putting it together:

1. LangGraph builds the state machine: nodes, edges, and the shared `MessagesState`.
2. `DaprWorkflowGraphRunner` wraps the compiled graph so each node execution becomes a **checkpointed Dapr Workflow activity** instead of an in-memory function call.
3. `runner.serve(...)` exposes it as an HTTP endpoint, and a pub/sub subscriber, via FastAPI.

---

You've read the whole graph without running a single command. Let's move on to challenge 3 where you'll actually run it and watch the durability layer in action.
