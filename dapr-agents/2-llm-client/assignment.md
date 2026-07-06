In this challenge, you'll use the simplest way to call an LLM using the Dapr Chat Client, which sends prompts through the Dapr Conversation API. It’s a minimal starting point before introducing agents in later challenges. This hands-on challenge takes about 5 minutes to complete.

> [!IMPORTANT]
> On the left you should see an *Editor* tab with the sample code, and a *Terminal* where you run commands. If a window isn't available — or you hit any blocking issue during this course — send me [an email](mailto:marc@diagrid.io) and we'll figure it out together.

![Dapr Conversation API Concept](https://docs.dapr.io/images/conversation-overview.png)

It's important to understand that the `DaprChatClient` is a client-side wrapper that internally uses the Dapr Conversation API to communicate with the Dapr sidecar, which in turn interacts with LLM providers through Dapr conversation components.

## 1. Get your LLM API key

To work with LLMs, you first need to sign up with an LLM provider and obtain an API key. Dapr Agents supports multiple providers, and the next section shows how to configure either OpenAI, Anthropic, GoogleAI, or HuggingFace. More providers are supported though, see the note at the end of step 2.

## 2. Configure the Conversation Component

Now you need to configure Dapr Conversation component with the API key of the LLM provider you want to use.

Open the `resources/llm-provider.yaml` file in **Editor** window.

This file is currently configured to use Ollama, but let's update to component file to use the LLM provider of your liking.

Expand the instructions below for the LLM provider you want to use and ensure you have an API key for that provider.

<details>
   <summary><b>OpenAI</b></summary>

Ensure that the `metadata` section matches to the example shown below and you replace <API_KEY> with your OpenAI API key.

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: llm-provider
spec:
  type: conversation.openai
  metadata:
  - name: key
    value: <API_KEY>
  - name: model
    value: gpt-4o-mini
```

</details>

<details>
   <summary><b>Anthropic</b></summary>

Ensure that the `metadata` section matches to the example shown below and you replace <API_KEY> with your Anthropic API key.

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: llm-provider
spec:
  type: conversation.anthropic
  metadata:
  - name: key
    value: <API_KEY>
  - name: model
    value: claude-sonnet-4-6
```

</details>

<details>
   <summary><b>GoogleAI</b></summary>

Ensure that the `metadata` section matches to the example shown below and you replace <API_KEY> with your Gemini API key.

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: llm-provider
spec:
  type: conversation.googleai
  metadata:
  - name: key
    value: <API_KEY>
  - name: model
    value: gemini-3-flash-preview
```

</details>

<details>
   <summary><b>HuggingFace</b></summary>

Ensure that the `metadata` section matches to the example shown below and you replace <API_KEY> with your HuggingFace API key.

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: llm-provider
spec:
  type: conversation.huggingface
  metadata:
  - name: key
    value: <API_KEY>
  - name: model
    value: meta-llama/Meta-Llama-3-8B
```

</details>

> [!NOTE]
> The component configuration tells Dapr how to connect to the LLM provider, which model to use, and other provider-specific settings. If you want to use a different LLM provider, you can change the component configuration file and update the `type` and `metadata` accordingly. See the [Dapr Conversation Components documentation](https://docs.dapr.io/reference/components-reference/supported-conversation/) for more details.

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
