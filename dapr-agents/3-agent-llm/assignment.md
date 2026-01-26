In this challenge, you'll explore the basic concept of a Dapr Agent. An agent wraps an LLM with a name, role, and instructions that define how it should behave. Unlike the previous example—where you called the LLM directly—an agent provides a reusable interface you can trigger multiple times, and it will consistently act according to its assigned role.

## Basic Agent with LLM

Running the script constructs an agent with a defined role and behavior, sends it a weather-related prompt, and prints its response. Because the agent has no tools, the LLM simply makes a best-effort guess about the weather based on its internal knowledge.

### Inspect the code

Open the `02_agent_llm.py` file in the **Editor** window.

### How this works

1. The agent is created with a name, a role, and a set of instructions that act as system-level guidance for how it should respond.
2. Internally, the agent uses the DaprChatClient, so each agent invocation sends a prompt through the Dapr Conversation API and receives the LLM’s response.

### Run the example

Use the **Terminal** window to create and activate a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Use the **Terminal** window to run the agent example:

```bash,run
dapr run --app-id agent-llm --resources-path resources -- python 02_agent_llm.py
```

### Expected output

You should see output similar to this:

```text,nocopy
== APP == user:
== APP == What's a quick weather update for London right now?
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == Currently in London, it's mostly cloudy with temperatures around 7°C (45°F). There's a light breeze, and only a slight chance of rain.
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Agent: content="Currently in London, it's mostly cloudy with temperatures around 7°C (45°F). There's a light breeze, and only a slight chance of rain." role='assistant'
```

The exact responses may vary, but you should see three different responses to the three different prompting approaches. This demonstrates how you can interact with LLMs in varying levels of complexity depending on your application's needs.

---

You've now learned how to use a basic Dapr agent with a name, role and instructions. In the next challenge, you'll learn how to use a Dapr agent that uses a local Python function as a tool.
