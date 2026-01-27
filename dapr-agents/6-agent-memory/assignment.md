This challenge shows how to use an agent that can store and recall its full conversation history across multiple interactions using a Dapr state store. By persisting the session history, the agent can continue a multi-turn dialog and provide answers informed by prior messages.

## 1. Inspect the code

Open the `05_agent_memory.py` file in the **Editor** window.

The script runs two prompts in sequence: the agent answers the initial weather question and persists the entire conversation history to the external state store. When the second prompt is sent—whether during the same run or after restarting the agent—it loads the stored session history and responds using that previously saved context.

### How This Works

1. The agent persists the full conversation history to a Dapr state store after each interaction, making the session durable across process restarts.
2. Each call to `weather_agent.run()` retrieves any previously stored history, allowing the agent to continue the conversation seamlessly.
3. The agent still performs tool calls as in earlier examples, but the LLM’s response now considers the restored session history.

## 2. Run the code

Use the **Terminal** window to create and activate a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

To run the example, use the following command in the **Terminal** window:

```bash,run
dapr run --app-id agent-memory --resources-path resources -- python 05_agent_memory.py
```

## 3. Inspect the output

You should see output similar to:

```text, nocopy
== APP == user:
== APP == I like warm and dry places. What is the weather in London now?
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == Function name: WeatherFunc (Call Id: call_dvf6i02hI2vcDB95UEnFK50C)
== APP == Arguments: {"location":"London"}
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherFunc(tool) (Id: call_dvf6i02hI2vcDB95UEnFK50C):
== APP == London: 68F.
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == The current temperature in London is 68°F. If you want to know more details like whether it's dry or humid, let me know!
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Agent: content="The current temperature in London is 68°F. If you want to know more details like whether it's dry or humid, let me know!" role='assistant'
== APP == user:
== APP == Given my preference, is London’s current weather a good match?
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == WeatherAgent(assistant):
== APP == Based on your preference for warm and dry places, London’s current temperature of 68°F (20°C) might be comfortable for some, but it’s not considered particularly warm by most standards—especially compared to classic warm and dry destinations (such as those above 75°F/24°C).
== APP == 
== APP == Also, London is generally known for its variable and sometimes humid climate, not typically for consistently warm and dry weather. I don’t have the humidity or precipitation levels at this moment, but it’s likely not matching your preference for a warm and dry climate.
== APP == 
== APP == If you'd like, I can recommend other cities with a more suitable climate for your tastes or check more weather details for London—just let me know!
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Agent: content="Based on your preference for warm and dry places, London’s current temperature of 68°F (20°C) might be comfortable for some, but it’s not considered particularly warm by most standards—especially compared to classic warm and dry destinations (such as those above 75°F/24°C).\n\nAlso, London is generally known for its variable and sometimes humid climate, not typically for consistently warm and dry weather. I don’t have the humidity or precipitation levels at this moment, but it’s likely not matching your preference for a warm and dry climate.\n\nIf you'd like, I can recommend other cities with a more suitable climate for your tastes or check more weather details for London—just let me know!" role='assistant'
```

---

You've now learned how to persist conversation history to a state store. Let's move on to the next challenge, where you learn to use durable agents.