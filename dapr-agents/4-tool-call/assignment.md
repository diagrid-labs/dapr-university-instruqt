In this challenge, you'll create an Agent; a stateless AI agent that can respond to user questions by directly invoking custom tools, such as retrieving weather information for different locations. This agent is ideal for lightweight, reactive tasks that require quick and direct tool execution.

### Prerequisite

> [!IMPORTANT]
> Open the `.env` file in the current folder and validate the `OPENAI_API_KEY` value is present. If it is not present, update with your actual OpenAI API key.

## 1. Examine Tool Definitions

Open the `weather_tools.py` file in the **Editor** window and note:
   - The `@tool` decorator that marks a function as a tool
   - The Pydantic model (`GetWeatherSchema`) that defines input parameters
   - The function that implements the weather lookup logic

```python,nocopy
@tool(args_model=GetWeatherSchema)
def get_weather(location: str) -> str:
    """Get weather information based on location."""
    import random
    temperature = random.randint(60, 80)
    return f"{location}: {temperature}F."
```

Each tool has a descriptive docstring that helps the LLM understand when to use it.

## 2. Examine the Agent Definition

Open the `weather_agent_dapr.py` file in the **Editor** window:

```python,nocopy
AIAgent = Agent(
    name="Stevie",
    role="Weather Assistant",
    goal="Assist Humans with weather related tasks.",
    instructions=[
        "Get accurate weather information",
        "From time to time, you can also jump after answering the weather question.",
    ],
    memory=ConversationDaprStateMemory(store_name="historystore", session_id="some-id"),
    tools=tools
)
```

Notice how we:

- Give the agent a name, role, and goal
- Provide specific instructions
- Configure persistent memory using Dapr state
- Provide our custom tools

## 3. Configure the Dapr State Store

1. Examine the `components/historystore.yaml` file in the **Editor** window:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: historystore
spec:
  type: state.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
```

This configuration tells Dapr to use Redis as the state store for agent conversation memory.

## 4. Run the Agent

Use the **Terminal** window to create and activate a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Use the **Terminal** window to navigate to the 03-agent-tool-call folder:

```bash,run
cd 03-agent-tool-call
```

Use the **Terminal** window to install the dependencies:

```bash,run
uv sync --active
```

Use the **Terminal** window to run the agent with Dapr as a sidecar:

```bash,run
dapr run --app-id weatheragent --resources-path ./components -- python3 weather_agent_dapr.py
```

## 5. Observe the Tool Calling Process

Examine the output in the **Terminal** window. You should see something similar to this:

```text,nocopy
== APP == user:
== APP == What is the weather in Virginia, New York and Washington DC?
== APP ==
== APP == --------------------------------------------------------------------------------
== APP ==
== APP == assistant:
== APP == Function name: GetWeather (Call Id: call_GCzCg1lVgdt1UGCKpCkQxqk8)
== APP == Arguments: {"location": "Virginia"}
== APP ==
== APP == --------------------------------------------------------------------------------
== APP ==
== APP == assistant:
== APP == Function name: GetWeather (Call Id: call_LZiV6s0kPiuIiUkKA6joCjnS)
== APP == Arguments: {"location": "New York"}
== APP ==
== APP == --------------------------------------------------------------------------------
== APP ==
== APP == assistant:
== APP == Function name: GetWeather (Call Id: call_zcvdD8rPmNE2Fxh8XBaxkIm7)
== APP == Arguments: {"location": "Washington DC"}
== APP ==
== APP == --------------------------------------------------------------------------------
== APP ==
== APP == GetWeather(tool) (Id: call_GCzCg1lVgdt1UGCKpCkQxqk8):
== APP == Virginia: 74F.
== APP ==
== APP == --------------------------------------------------------------------------------
== APP ==
== APP == GetWeather(tool) (Id: call_LZiV6s0kPiuIiUkKA6joCjnS):
== APP == New York: 68F.
== APP ==
== APP == --------------------------------------------------------------------------------
== APP ==
== APP == GetWeather(tool) (Id: call_zcvdD8rPmNE2Fxh8XBaxkIm7):
== APP == Washington DC: 68F.
== APP ==
== APP == --------------------------------------------------------------------------------
== APP ==
== APP == assistant:
== APP == The current weather is as follows:
== APP == - **Virginia:** 74°F
== APP == - **New York:** 68°F
== APP == - **Washington DC:** 68°F
== APP ==
== APP == If you need anything else, feel free to ask!
== APP ==
== APP == --------------------------------------------------------------------------------
```

Notice how the agent:

1. Identifies that it needs weather information for each location
2. Calls the `get_weather` tool multiple times with different parameters
3. Combines the results into a coherent response

---
You've now learned how to use an Agent; a stateless AI agent that can respond to user questions by directly invoking custom tools. In the next challenge, you'll learn how to build agents that can call external services through Model Context Protocol (MCP).
