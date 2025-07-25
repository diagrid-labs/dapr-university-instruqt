In this challenge, you'll learn how to connect your agent to external systems using the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/introduction). You'll see how agents can use MCP to access tools running in separate processes, such as scripts, databases, or APIs, and how to use the STDIO transport for local development.

### Prerequisite

> [!IMPORTANT]
> Open the `.env` file in the current folder and validate the `OPENAI_API_KEY` value is present. If it is not present, update it with your actual OpenAI API key.

## 1. What is MCP?

The **Model Context Protocol (MCP)** is a standard for connecting AI agents to external tools and systems. MCP allows agents to:
- Discover and use tools provided by other processes or services
- Communicate with tools over different transports (local or networked)
- Integrate with databases, APIs, scripts, and more

With MCP, agents can go beyond built-in Python functions and interact with a wide range of external capabilities, all exposed as tools.

### Key Concepts
Before diving into the code, let's cover the key concepts:

- **MCP Server**: A process that exposes tools using the MCP protocol. This could be a script, a database connector, or any service that implements MCP.
- **MCP Client**: A component that connects to an MCP server, discovers its tools and makes them available to agents.
- **Transports**: MCP supports multiple ways to connect:
  - **STDIO**: Communicates over standard input/output (local subprocess, no network needed). Great for local development and testing.
  - **SSE (Server-Sent Events)**: Communicates over HTTP for distributed or networked tools.

In this example, you'll use **STDIO** transport, which means the agent will launch a local MCP server as a subprocess and communicate with it over the command line.


## Step 1: Explore MCP Tools (tools.py)

Open the `tools.py` file in the **Editor** window to see how to define an MCP server using FastMCP.

```python,nocopy
from mcp.server.fastmcp import FastMCP
import random

mcp = FastMCP("TestServer")

@mcp.tool()
async def get_weather(location: str) -> str:
    """Get weather information for a specific location."""
    temperature = random.randint(60, 80)
    return f"{location}: {temperature}F."

@mcp.tool()
async def jump(distance: str) -> str:
    """Simulate a jump of a given distance."""
    return f"I jumped the following distance: {distance}"

# When run directly, serve tools over STDIO
if __name__ == "__main__":
    mcp.run("stdio")
```

## 2. Understanding MCP Capabilities

MCP supports different types of capabilities that can be exposed to agents:

- **Tools**: Executable functions that allow LLMs to perform actions like calling APIs, making calculations, or executing code. 
- **Resources**: Similar to tools but designed for read-only access to data sources like files, databases, or configuration. 
- **Other capabilities**: MCP can also expose prompts, sampling configurations, and other specialized capabilities depending on the implementation.

## How Tools Work

- The `FastMCP` class creates an MCP server named "TestServer" that exposes Python functions as executable capabilities for LLM clients. When an LLM decides to use a tool, it sends a request with parameters, FastMCP validates these against the function's signature, executes the function, and returns the result.
- The `@mcp.tool()` decorator transforms regular Python functions into MCP tools that LLMs can invoke during conversations. FastMCP automatically uses the function name as the tool name, generates an input schema from the function's parameters and type annotations, and handles parameter validation and error reporting.
- When you run this file directly, it starts the MCP server using STDIO transport, allowing the agent to communicate with the tools as a subprocess over standard input/output.
- The function's docstring (like `"""Get weather information for a specific location."""`) serves as the tool description that helps the LLM understand what the tool does and when to use it. The agent uses this description along with the function signature to determine which tool is appropriate for a given task and how to call it with the correct parameters.

## 3. Explore the MCP Client and Agent (agent.py)

Open the `agent.py` file in the **Editor** window to see how to connect to the MCP server and use its tools in an agent.

```python,nocopy
import asyncio
import logging
import sys
from dotenv import load_dotenv

from dapr_agents import Agent
from dapr_agents.tool.mcp import MCPClient

load_dotenv()

async def main():
    # Create the MCP client
    client = MCPClient()

    # Connect to MCP server using STDIO transport
    await client.connect_stdio(
        server_name="local",
        command=sys.executable,  # Use the current Python interpreter
        args=["tools.py"],  # Run tools.py directly
    )

    # Get available tools from the MCP instance
    tools = client.get_all_tools()
    print("🔧 Available tools:", [t.name for t in tools])

    # Create the Weather Agent using MCP tools
    weather_agent = Agent(
        name="Stevie",
        role="Weather Assistant",
        goal="Help humans get weather and location info using MCP tools.",
        instructions=[
            "Respond clearly and helpfully to weather-related questions.",
            "Use tools when appropriate to fetch or simulate weather data.",
            "You may sometimes jump after answering the weather question.",
        ],
        tools=tools,
    )

    # Run a sample query
    result = await weather_agent.run("What is the weather in New York?")
    print(result)

    # Clean up resources
    await client.close()

if __name__ == "__main__":
    asyncio.run(main())
```

- The `MCPClient` connects to the local MCP server (tools.py) using STDIO.
- It discovers all available capabilities and exposes them to the agent as regular tools we saw in the previous example.
- The agent can now use these tools as if they were built-in Python functions.

## 4. Run the Example

Use the **Terminal** window to run create a virtual environment:

```bash,run
python3 -m venv .venv
source .venv/bin/activate
```

Use the **Terminal** window to install the dependencies:

```bash,run
pip install -r requirements.txt
```

To run the example, use the following command in the **Terminal** window:

```bash,run
python3 agent.py
```

You should see output similar to:

```text, nocopy
 Available tools: ['LocalGetWeather', 'LocalJump']
user:
What is the weather in New York?

--------------------------------------------------------------------------------

assistant:
Function name: LocalGetWeather (Call Id: call_mvCDq5TIJhAKXEVy9enfjSkf)
Arguments: {"location":"New York"}

--------------------------------------------------------------------------------

INFO     Processing request of type CallToolRequest                server.py:556
LocalGetWeather(tool) (Id: call_mvCDq5TIJhAKXEVy9enfjSkf):
New York: 75F.

--------------------------------------------------------------------------------

assistant:
The current temperature in New York is 75°F.

--------------------------------------------------------------------------------

The current temperature in New York is 75°F.
```

## 5. How It Works

- The agent launches the tools.py script as a subprocess.
- The MCP client connects to the subprocess using STDIO.
- The agent receives your query, determines which MCP tool to use, and sends the request to the tools subprocess.
- The tools subprocess executes the tool and returns the result.
- The agent formulates a response based on the tool result.

## Alternative: Using SSE Transport

> [!NOTE]
> While this example uses STDIO for local development, MCP also supports Server-Sent Events (SSE) for network-based communication. SSE is useful when tools need to run as separate services or on different machines.

When connecting to an external MCP server using SSE, only the connection code differs:

```python,nocopy
# Instead of connect_stdio, use connect_sse for network-based MCP servers
await client.connect_sse("local", url="http://localhost:8000/sse")
```

The rest of your agent code remains exactly the same! Once connected, the agent interacts with remote tools just like local ones.

---

 You've now learned how to connect your agent to external tools using the Model Context Protocol (MCP). Let's move on to the next challenge, where you learn to create durable agents for critical tasks.