This challenge takes the same durable agent behavior from the previous challenge, but instead of exposing an HTTP endpoint, it uses pub/sub. With this setup, the durable agent runs in the background as an ambient agent and listens for incoming events on a message topic. When a message arrives, it automatically starts a workflow execution.

## 1.  Explore the DurableAgent

Use the **Editor** window to examine the durable agent implementation in the `03_durable_agent_pubsub.py` file.

The agent code remains largely unchanged; only the `AgentRunner` configuration switches from REST to pub/sub, and an `AgentPubSubConfig` is added.

```python,nocopy
pubsub=AgentPubSubConfig(
      pubsub_name="agent-pubsub",
      agent_topic="weather.requests",
      broadcast_topic="agents.broadcast",
),

...

runner = AgentRunner()
    try:
        runner.subscribe(weather_agent)
        await wait_for_shutdown()
    finally:
        runner.shutdown()
```

## 3. Run the Durable Agent

Use the **Terminal Subscriber** window to create a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Run the durable agent with Dapr by running this command in the **Terminal Subscriber** window:

```bash,run
dapr run --app-id durable-agent-subscriber --resources-path resources --dapr-http-port 3500 -- python 03_durable_agent_pubsub.py
```

## 4. Publish a message to trigger the agent

Use the **Terminal Publisher** window to create a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Publish a message running this command in the **Terminal Publisher** window:

```bash,run
dapr publish --publish-app-id durable-agent-subscriber --pubsub agent-pubsub --topic weather.requests --data '{"task": "What is the weather in London?"}'
```

The **Terminal Subscriber** window will show logs similar to this:

```text,nocopy
on-behalf-of durable-agent-subscriber(user):
What is the weather in London?

--------------------------------------------------------------------------------

WeatherAgent(assistant):

Function name: SlowWeatherFunc (Call Id: call_iCvyFdoYWXCFxGimhmXlOAPh)
Arguments: {"location":"London"}


--------------------------------------------------------------------------------

SlowWeatherFunc(tool) (Id: call_iCvyFdoYWXCFxGimhmXlOAPh):
London: 61F.

--------------------------------------------------------------------------------

WeatherAgent(assistant):
The current weather in London is 61°F.

--------------------------------------------------------------------------------
```

> [!IMPORTANT]
> Use `CTRL+C` in both terminals to stop the applications.

## 5. How This Works

1. The agent runs as a durable agent subscribed to a pub/sub topic and listens for incoming events.
2. A message is published to the topic using the dapr publish command.
3. The agent runner receives the event and forwards it to the durable agent.
4. The message triggers a workflow execution, which performs the LLM and tool-call activities with durable state persisted at every step.

---

You've now learned about using durable AI agents that are triggered by subscribing to pub/sub messages. Let's move on to the next challenge where you'll use a workflow that chains together multiple AI tasks.