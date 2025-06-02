In this challenge, you'll create a ToolCallAgent—a stateless AI agent that can respond to user questions by directly invoking custom tools, such as retrieving weather information for different locations. This agent is ideal for lightweight, reactive tasks that require quick and direct tool execution.

### Prerequisite

> [!IMPORTANT]
> Open the `.env` file in the current folder and validate the `OPENAI_API_KEY` value is present. If it is not present, update with your actual OpenAI API key.

The `OPENAI_API_KEY` is required for the examples to communicate with OpenAI's services.

## 1. Examine Tool Definitions

1. Open the `weather_tools.py` file in the **Editor** window and note:
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
    pattern="toolcalling",
    tools=tools
)
```

The Agent class acts as a factory that can create different types of agents depending on the pattern you specify. While the ToolCallAgent is the default, here we explicitly set the pattern to `toolcalling` to make it clear that we want an agent specialized in handling tool calls for tasks like retrieving weather information.

Notice how we:

- Give the agent a name, role, and goal
- Provide specific instructions
- Configure persistent memory using Dapr state
- Set the agent pattern to "toolcalling"
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

## 4. Run the Tool Calling Agent

Use the **Terminal** window to run create a virtual environment:

```bash,run
python3 -m venv .venv
source .venv/bin/activate
```

Use the **Terminal** window to install the dependencies:

```bash,run
pip install -r requirements.txt
```

Use the **Terminal** window to run the agent with Dapr as a sidecar:

```bash,run
dapr run --app-id weatheragent --resources-path ./components -- python3 weather_agent_dapr.py
```

## 5. Observe the Tool Calling Process

Examine the output in your terminal. You should see:

```text,nocopy
user:
What is the weather in Virginia, New York and Washington DC?
assistant:
Function name: GetWeather (Call Id: 1)
Arguments: {"location": "Virginia"}
GetWeather(tool)
Virginia
GetWeather(tool)
New York
GetWeather(tool)
Washington DC
I'll check the weather for you in Virginia, New York, and Washington DC.

Here's the current weather information:
- Virginia: 72F
- New York: 67F
- Washington DC: 75F

Let me know if you need weather information for any other locations!
```

Notice how the agent:

1. Identifies that it needs weather information for each location
2. Calls the `get_weather` tool multiple times with different parameters
3. Combines the results into a coherent response

In the next challenge, you'll learn how to build agents that can call external services through Model Context Protocol (MCP).
