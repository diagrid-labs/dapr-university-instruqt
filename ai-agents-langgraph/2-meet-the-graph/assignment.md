LangGraph's whole point is the graph, so before running anything, let's go through one. You'll only use the Editor window in challenge to read the code. This challenge takes about 6 minutes.

## 1. Open the files

The graph is spread over three files. `main.py` builds and wires the graph, `tools.py` holds the agent's tools, and `fake_model.py` holds the canned offline model. Open all three in the **Editor** as you go.

## 2. Inspect the tool

Open `tools.py` in the **Editor** and look at lines 11-18:

```python,nocopy
@tool
def check_availability(venue: str, date: str) -> str:
    """Check venue availability for a specific date."""
    return f"{venue} is available on {date}. Time slots: 9AM-1PM, 2PM-6PM, 6PM-11PM."


tools = [check_availability]
tools_by_name = {t.name: t for t in tools}
```

A LangGraph tool is just a Python function decorated with `@tool`. The model never calls this function directly. It decides *when* to call it and *with what arguments*, and LangGraph runs it on the model's behalf. `tools_by_name` is the lookup one of the graph's nodes uses to find the matching Python function when a tool call comes back.

## 3. Choose the model

In `main.py`, look at lines 13-25:

```python,nocopy
def build_model():
    """Real provider on request, canned model otherwise."""
    if os.environ.get("DIAGRID_QUICKSTART_MODEL") == "openai":
        from langchain_openai import ChatOpenAI

        logging.info("Using OpenAI (gpt-4.1-mini).")
        return ChatOpenAI(model="gpt-4.1-mini")

    logging.info(
        "Using the canned offline model: no API key needed and the answer is "
        "always the same. Set DIAGRID_QUICKSTART_MODEL=openai for a real provider."
    )
    return build_canned_model()
```

This returns the canned model from `fake_model.py` (unless you set `DIAGRID_QUICKSTART_MODEL=openai` and provide an OpenAI API key). Open `fake_model.py` and look at lines 47-58:

```python,nocopy
    def _generate(
        self,
        messages: list[BaseMessage],
        stop: list[str] | None = None,
        run_manager: Any = None,
        **kwargs: Any,
    ) -> ChatResult:
        tool_has_run = any(isinstance(m, ToolMessage) for m in messages)
        turn = self.final_turn if tool_has_run else self.first_turn
        # Copy, never hand out the field itself: BaseChatModel stamps an `id` on
        # the message it returns, mutating it in place.
        return ChatResult(generations=[ChatGeneration(message=turn.model_copy(deep=True))])
```

Two canned turns: ask for the tool, then answer from the tool's result. Note *how* it decides which turn to return. It reads the conversation for a `ToolMessage` rather than counting how many times it has been called. That matters here more than it would in a plain LangGraph app: each node runs as a Dapr Workflow activity, so after a crash the replayed message history is the only state that survived. A call counter would reset with the process and ask for the tool a second time.

## 4. Bind the tool to the model

Look at line 28 in `main.py`:

```python,nocopy
model = build_model().bind_tools(tools)
```

`bind_tools(tools)` is what makes a model aware the tool exists. For a real provider, LangChain turns each `@tool` function into a JSON schema and sends it along with every request, so the model can answer with a *tool call* instead of text. The canned model accepts the binding and ignores it, because the tool call it returns is already decided.

## 5. Inspect the nodes

Look at lines 31-42 in `main.py`. There are two functions here, each a **node** in the graph:

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

`call_model` sends the conversation so far to the model. `call_tools` executes whatever tool calls the model asked for. Each is a plain function that reads the shared `MessagesState` and returns updates to it. That's all a LangGraph node is.

## 6. Inspect the routing

Look at lines 45-49 in `main.py`:

```python,nocopy
def should_use_tools(state: MessagesState) -> str:
    last_message = state["messages"][-1]
    if hasattr(last_message, "tool_calls") and last_message.tool_calls:
        return "tools"
    return "__end__"
```

`should_use_tools` decides where to go after `call_model` runs. It goes back to `tools` if the model asked for a tool call, or ends the graph if it didn't. This is the **conditional edge** that creates the tool-calling loop. Without it, the graph would only ever run once.

## 7. Inspect the graph construction

Look at lines 52-57:

```python,nocopy
graph = StateGraph(MessagesState)
graph.add_node("agent", call_model)
graph.add_node("tools", call_tools)
graph.add_edge(START, "agent")
graph.add_conditional_edges("agent", should_use_tools)
graph.add_edge("tools", "agent")
```

Nodes are registered, then edges are wired: `START → agent → (conditional) → tools → agent → …`. The graph keeps looping between `agent` and `tools` until `should_use_tools` returns `__end__`.

## 8. Inspect the runner

Look at lines 59-76:

```python,nocopy
runner = DaprWorkflowGraphRunner(
    graph=graph.compile(),
    name="schedule-planner",
    role="Schedule Planner",
    goal="Check venue date and time availability using the check_availability tool. Provide available time slots for a given venue and date.",
)

# Guarded so this module can be imported without starting a server. The tests import
# check_availability from here to assert against the real tool rather than a copy of it.
if __name__ == "__main__":
    # State + PubSub: subscribe for incoming tasks, publish results
    runner.serve(
        port=int(os.environ.get("APP_PORT", "8005")),
        input_mapper=lambda req: {"messages": [HumanMessage(content=req["task"])]},
        pubsub_name="pubsub",
        subscribe_topic="schedule.requests",
        publish_topic="schedule.results",
    )
```

`DaprWorkflowGraphRunner(...)` wraps the compiled graph. That one call is the entire durability layer, and you'll see what it actually does in challenge 3. `runner.serve(...)` starts an HTTP server on port `8005` and subscribes to the `schedule.requests` pub/sub topic, so the same graph can be triggered either way. It sits behind an `if __name__ == "__main__":` guard so the module can be imported without starting a server.

## 9. How this works

Putting it together:

1. LangGraph builds the state machine: nodes, edges, and the shared `MessagesState`. `build_model()` decides which model those nodes talk to.
2. `DaprWorkflowGraphRunner` wraps the compiled graph so each node execution becomes a **checkpointed Dapr Workflow activity** instead of an in-memory function call.
3. `runner.serve(...)` exposes it as an HTTP endpoint, and a pub/sub subscriber, via FastAPI.

---

You've read the whole graph now. Let's move on to challenge 3 where you'll run the graph and watch the durability layer in action.
