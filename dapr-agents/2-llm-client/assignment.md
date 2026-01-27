In this challenge, you'll use the simplest way to call an LLM using the Dapr Chat Client, which sends prompts through the Dapr Conversation API. It’s a minimal starting point before introducing agents in later challenges.

![Dapr Conversation API Concept](https://docs.dapr.io/images/conversation-overview.png)

It's important to understand that the `DaprChatClient` is a client-side wrapper that internally uses the Dapr Conversation API to communicate with the Dapr sidecar, which in turn interacts with LLM providers through Dapr conversation components.

## 1. Get your OpenAI API key

To work with LLMs, you first need to sign up with an LLM provider and obtain an API key. Throughout this challenge, we'll be using OpenAI's models, but Dapr Agents supports multiple providers. If you wish to use a different provider, see the [Dapr Conversation Components documentation](https://docs.dapr.io/reference/components-reference/supported-conversation/) for more options.

You can get an OpenAI API key by signing up at [OpenAI](https://platform.openai.com/signup).

## 2. Configure the OpenAI Component

Now we need to configure the OpenAI component with your API key:

Open the `resources/llm-provider.yaml` file in **Editor** window.

This file contains the Dapr component configuration for OpenAI. Update the `key` value with your actual OpenAI API key, then save the file.

The component configuration tells Dapr how to connect to OpenAI, which model to use, and other provider-specific settings.

> [!NOTE]
> If you want to use a different LLM provider, you can change the component configuration file and update the `type` and `metadata` accordingly. See the [Dapr Conversation Components documentation](https://docs.dapr.io/reference/components-reference/supported-conversation/) for more details.

## 3. Inspect the DaprChatClient Code

Open the `01_llm_client.py` file in the **Editor** window.

This file demonstrates:

- How to initialize a `DaprChatClient` that uses Dapr's Conversation API
- Basic text generation with a prompt

This python code sends a request to the Dapr sidecar, which then handles the communication with the LLM provider based on your component configuration.

### How this works

1. The `DaprChatClient` sends requests to the Dapr sidecar using the Dapr Conversation API
2. The Dapr sidecar processes these requests using the appropriate conversation component (e.g., `conversation.openai`, `conversation.echo`, etc.)
3. The conversation component handles the specifics of communicating with the LLM provider
4. Results flow back through the same path to your application

This abstraction layer allows you to switch between different LLM providers by simply changing the component configuration, without modifying your application code.

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

You should see output similar to this:

```text,nocopy
== APP == Response:  I don’t have real-time data access, so I can’t know exactly what the weather in London is right now. But if I had to guess based on typical June weather: It might be around 15-22°C (59-72°F), with partly cloudy skies and a chance of rain—because, well…it’s London!
== APP == 
== APP == If you want the exact weather, try checking a weather website or ask your smart assistant at home!
```

The exact responses may vary, but you should see three different responses similar to the direct OpenAI client example.

## 6. Benefits of the Dapr Approach

Using the Dapr Conversation API instead of calling LLMs directly offers several advantages:

1. **Provider Flexibility**: Switch between different LLM providers (OpenAI, Anthropic, Azure, etc.) by simply changing component configuration, without modifying your code.

2. **Caching**: Dapr can cache responses for identical prompts, reducing costs and latency.

3. **PII Obfuscation**: Personal identifiable information (such as phone number, email address, social security number, etc) can be automatically removed from prompts and responses.

4. **Resiliency**: Built-in or custom-defined retry policies, timeouts, and circuit breakers make your applications more robust against LLM service outages.

5. **Tracing**: Dapr's observability features help you monitor and debug LLM interactions.

6. **Secret Management**: API keys can be securely retrieved through Dapr's secret store rather than in the application or component code.

---

You've now used the `DaprChatClient` which is a wrapper around the Dapr Conversation API to interact with LLMs. In the next challenge, you'll learn how to use an agent to interact with an LLM.
