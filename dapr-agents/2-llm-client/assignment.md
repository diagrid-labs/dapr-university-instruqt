In this challenge, you'll use the simplest way to call an LLM using the Dapr Chat Client, which sends prompts through the Dapr Conversation API. It’s a minimal starting point before introducing agents in later challenges. This hands-on challenge takes about 5 minutes to complete.

> [!IMPORTANT]
> On the left you should see an *Editor* tab with the sample code, and a *Terminal* where you run commands. If a window isn't available — or you hit any blocking issue during this course — send me [an email](mailto:marc@diagrid.io) and we'll figure it out together.

![Dapr Conversation API Concept](https://docs.dapr.io/images/conversation-overview.png)

It's important to understand that the `DaprChatClient` is a client-side wrapper that internally uses the Dapr Conversation API to communicate with the Dapr sidecar, which in turn interacts with LLM providers through Dapr conversation components.

## 1. Inspect the Conversation component

The Dapr sidecar talks to the LLM provider through a Dapr Conversation component. An OpenAI API key has already been provisioned for this sandbox, so you don't need to bring your own.

Open the `resources/llm-provider.yaml` file in the **Editor** window:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: llm-provider
spec:
  type: conversation.openai
  version: v1
  metadata:
  - name: key
    secretKeyRef:
      name: openai-api-key
      key: openai-api-key
  - name: model
    value: gpt-4.1-mini
auth:
  secretStore: local-secret-store
```

The component uses the `conversation.openai` type with the `gpt-4.1-mini` model. The API key isn't written in the component file. Instead, `secretKeyRef` tells Dapr to look up the `openai-api-key` secret in the `local-secret-store` secret store.

## 2. Inspect the secret store component

Open the `resources/local-secret-store.yaml` file in the **Editor** window:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: local-secret-store
spec:
  type: secretstores.local.file
  version: v1
  metadata:
  - name: secretsFile
    value: secrets.json
```

This is a local file secret store that reads secrets from the `secrets.json` file in the quickstarts folder (the path is relative to the folder you run `dapr run` from). It's convenient for local development; in production you'd use a secret store such as HashiCorp Vault, Azure Key Vault, or AWS Secrets Manager, without changing the conversation component.

> [!NOTE]
> The component configuration tells Dapr how to connect to the LLM provider, which model to use, and other provider-specific settings. Dapr supports many other LLM providers, such as Anthropic, Google AI, Mistral, and Hugging Face. To use one of these, you change the `type` and `metadata` of the component while keeping the component name `llm-provider`; your application code stays the same. In this sandbox only an OpenAI API key is provisioned. See the [Dapr Conversation Components documentation](https://docs.dapr.io/reference/components-reference/supported-conversation/) for more details.

## 3. Inspect the DaprChatClient Code

Open the `01_llm_client.py` file in the **Editor** window.

This file demonstrates:

- How to initialize a `DaprChatClient` that uses Dapr's Conversation API
- Basic text generation with a prompt

This python code sends a request to the Dapr sidecar, which then handles the communication with the LLM provider based on your component configuration.

## 4. Run the Dapr Chat Client Example

Use the **Terminal** window to create and activate a virtual environment and install the dependencies:

```bash,run
uv venv
source .venv/bin/activate
uv sync --active
```

Use the **Terminal** window to run the text completion example with Dapr:

```bash,run
dapr run --app-id llm-client --resources-path resources -- python 01_llm_client.py
```

Notice that the command includes:

- `--app-id`: Identifies your application to Dapr
- `--resources-path`: Tells Dapr where to find your component configurations
- The Python file to execute

## 5. Expected Output

> [!NOTE]
> It will take a couple of seconds for the result to appear.

You should see output similar to this:

```text,nocopy
Response:  I don't have real-time data access to provide current weather conditions. For the most accurate and up-to-date weather information in London, I recommend checking a reliable weather website or app.
```

## 6. How this works

1. The DaprChatClient sends the prompt to the Dapr sidecar using the Conversation API under the hood.
2. The Dapr sidecar uses the configured conversation component to forward the prompt to the LLM provider (OpenAI in this challenge) and returns the generated response to your application.

This abstraction layer allows you to switch between different LLM providers by simply changing the component configuration, without modifying your application code.

## 7. Benefits of the Dapr Approach

Using the Dapr Conversation API instead of calling LLMs directly offers several advantages:

1. **Provider Flexibility**: Switch between different LLM providers (OpenAI, Anthropic, Azure, etc.) by simply changing component configuration, without modifying your code.

2. **Caching**: Dapr can cache responses for identical prompts, reducing costs and latency.

3. **PII Obfuscation**: Personal identifiable information (such as phone number, email address, social security number, etc) can be automatically removed from prompts and responses.

4. **Resiliency**: Built-in or custom-defined retry policies, timeouts, and circuit breakers make your applications more robust against LLM service outages.

5. **Tracing**: Dapr's observability features help you monitor and debug LLM interactions.

6. **Secret Management**: API keys can be securely retrieved through Dapr's secret store rather than in the application or component code.

---

You've now used the `DaprChatClient` which is a wrapper around the Dapr Conversation API to interact with LLMs. In the next challenge, you'll learn how to use an agent to interact with an LLM.
