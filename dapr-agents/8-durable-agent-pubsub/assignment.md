This challenge takes the same durable agent behavior from the previous challenge, but instead of exposing an HTTP endpoint, it uses pub/sub. With this setup, the durable agent runs in the background as an ambient agent and listens for incoming events on a message topic. When a message arrives, it automatically starts a workflow execution.

## 1.  Explore the DurableAgent

Use the **Editor** window to examine the durable agent implementation in the `07_durable_agent_pubsub.py` file.

The agent code remains unchanged; only the `AgentRunner` configuration switches from REST to pub/sub.

### How This Works

1. The agent runs as a durable agent subscribed to a pub/sub topic and listens for incoming events.
2. A message is published to the topic using the `dapr publish` command.
3. The agent runner receives the event and forwards it to the durable agent.
4. The message triggers a workflow execution, which performs the LLM and tool-call activities with durable state persisted at every step.

## 2. Pub/Sub Configuration

Let's explore the key components that enable pub/sub messaging in the `DurableAgent`:

```python,nocopy
pubsub=AgentPubSubConfig(
            pubsub_name="message-pubsub",
            agent_topic="weather.requests",
            broadcast_topic="agents.broadcast",
        ),
```

This configures the agent to use a pub/sub component file named `message-pubsub.yaml`. It will listen for incoming messages on the `weather.requests` topic and can also broadcast messages to the `agents.broadcast` topic.

**Component Configuration (message-pubsub.yaml)**:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: message-pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
```

## 3. Run the Durable Agent

Use the **Terminal Subscriber** window to create a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Run the durable agent with Dapr by running this command in the **Terminal Subscriber** window:

```bash,run
dapr run --app-id durable-agent-subscriber --resources-path resources --dapr-http-port 3500 -- python 07_durable_agent_pubsub.py
```

## 4. Publish a message to trigger the agent

Use the **Terminal Publisher** window to create a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Publish a message running this command in the **Terminal Publisher** window:

```bash,run
dapr publish --publish-app-id durable-agent-subscriber --pubsub message-pubsub --topic weather.requests --data '{"task": "What is the weather in London?"}'
```

---

You've now learned about using durable AI agents that are triggered by subscribing to pub/sub messages. Let's move on to the next challenge where you'll use a workflow that chains together multiple AI tasks.