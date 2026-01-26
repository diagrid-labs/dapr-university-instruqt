This challenge is very similar to the previous one, except that the agent does not use hard-coded Python functions as tools. Instead, it dynamically discovers its tools from an MCP (Model Context Protocol) server running locally over STDIO, allowing tools to be added or modified without changing the agent code.

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


## Step 1: Explore MCP Tools (mcp_tools.py)

Open the `mcp_tools.py` file in the **Editor** window to see how to define an MCP server using FastMCP.

```python,nocopy
from mcp.server.fastmcp import FastMCP
import random

mcp = FastMCP("TestServer")

@mcp.tool()
async def get_weather(location: str) -> str:
    """Get weather information for a specific location."""
    temperature = random.randint(60, 80)
    return f"{location}: {temperature}F."


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

## 3. Explore the MCP Client and Agent (04_agent_mcp_tools.py)

Open the `04_agent_mcp_tools.py` file in the **Editor** window to see how to connect to the MCP server and use its tools in an agent.

### How This Works

1. The agent connects to an MCP server over STDIO, allowing tools to be negotiated and loaded dynamically at runtime.
2. The weather tools are served by the local MCP script (`mcp_tools.py`), and the agent invokes them when the LLM requests a tool call.
3. The LLM call still goes through the Dapr Conversation API, giving the same provider abstraction as in Example 3 but with a more flexible tool architecture.

## 4. Run the Example

Use the **Terminal** window to create and activate a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

To run the example, use the following command in the **Terminal** window:

```bash,run
dapr run --app-id agent-mcp --resources-path resources -- python 04_agent_mcp_tools.py
```

## 5. Observe the Tool Calling Process

Examine the output in the **Terminal** window. You should see something similar to this:

```text, nocopy
== APP == [01/26/26 10:55:54] INFO     Processing request of type            server.py:713
== APP ==                              ListToolsRequest                                   
== APP ==                     INFO     Processing request of type            server.py:713
== APP ==                              ListPromptsRequest                                 
== APP == user:
== APP == What's a quick weather update for London right now?
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == Function name: LocalGetWeather (Call Id: call_uFsnUJxsX6QkgIlYgVE1Wxb0)
== APP == Arguments: {"location":"London"}
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == [01/26/26 10:55:58] INFO     Processing request of type            server.py:713
== APP ==                              CallToolRequest                                    
== APP ==                     INFO     Processing request of type            server.py:713
== APP ==                              ListToolsRequest                                   
== APP == 
== APP == LocalGetWeather(tool) (Id: call_uFsnUJxsX6QkgIlYgVE1Wxb0):
== APP == meta=None content=[TextContent(type='text', text='London: 63F.', annotations=None, meta=None)] structuredContent={'result': 'London: 63F.'} isError=False
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == Right now in London, it's 63°F. Would you like more details or a forecast?
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Agent: content="Right now in London, it's 63°F. Would you like more details or a forecast?" role='assistant'
```

When you run the script, the agent queries the MCP server for available tools, invokes the MCP-provided weather tool to answer the question, and uses the LLM to produce the final response.

---

You've now learned how to connect your agent to external tools using the Model Context Protocol (MCP). Let's move on to the next challenge, where you learn to create durable agents for critical tasks.