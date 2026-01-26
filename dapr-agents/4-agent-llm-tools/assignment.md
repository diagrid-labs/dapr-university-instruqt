In this challenge, you'll use an agent with a custom prompt, backed by the Dapr Conversation API, and how to use a local Python function as a tool the agent calls during reasoning. It demonstrates the simplest way to run an agent locally as a regular Python program while benefiting from Dapr’s LLM abstraction.

## 1. Examine Tool Definitions

Open the `function_tools.py` file in the **Editor** window and note:

- The `@tool` decorator that marks a function as a tool
- The function that implements the weather lookup logic

Each tool has a descriptive docstring that helps the LLM understand when to use it.

## 2. Examine the Agent Definition

Open the `03_agent_llm_tools.py` file in the **Editor** window:

### How this works

1. The agent sends prompts to the Dapr Conversation API, which routes them to the configured LLM provider without requiring changes to your application code.
2. A Python function is registered as a tool, and the agent executes it when the LLM decides a tool call is needed.
3. The interaction runs as a single-turn exchange with no persistence, serving as the minimal foundation for later examples.

## 3. Run the Agent

Use the **Terminal** window to create and activate a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Use the **Terminal** window to run the agent with Dapr as a sidecar:

```bash,run
dapr run --app-id agent-llm --resources-path resources -- python 03_agent_llm_tools.py
```

## 5. Observe the Tool Calling Process

Examine the output in the **Terminal** window. You should see something similar to this:

```text,nocopy
== APP == user:
== APP == What's a quick weather update for London right now?
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == Function name: WeatherFunc (Call Id: call_EqtldsIkvTerij3xuazqfvKc)
== APP == Arguments: {"location":"London"}
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherFunc(tool) (Id: call_EqtldsIkvTerij3xuazqfvKc):
== APP == London: 68F.
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == Right now in London, it's 68°F. Let me know if you need more details or a forecast!
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Agent: content="Right now in London, it's 68°F. Let me know if you need more details or a forecast!" role='assistant'
```

---
You've now learned how to use an agent that is using local tools. In the next challenge, you'll learn how to use an agent that uses MCP-based tools.
