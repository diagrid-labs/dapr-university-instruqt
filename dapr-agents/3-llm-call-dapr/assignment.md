# Using DaprChatClient for LLM Interactions

In this challenge, you'll explore how to use the Dapr Conversation API to interact with Large Language Models through the `DaprChatClient`. Unlike the previous example where we used OpenAI's client directly, we'll now use Dapr's provider-agnostic approach, which allows your code to work with any supported LLM without application modification. 

![Dapr Conversation API Concept](https://docs.dapr.io/images/conversation-overview.png)

It's important to understand that the `DaprChatClient` is a client-side wrapper that internally uses the Dapr Conversation API to communicate with the Dapr sidecar, which in turn interacts with LLM providers through Dapr conversation components.

## 1. Understanding the Environment Configuration

First, let's examine the environment configuration to see which LLM component we'll be using:

> [!NOTE]
> Open the `.env` file in the current folder.

The `DAPR_LLM_COMPONENT_DEFAULT` setting is already configured to use the `openai` component. This environment variable tells the `DaprChatClient` which Dapr component to use for LLM interactions. The value must match the `name` field in the metadata section of a component file in the `components` folder (for example, `components/openai.yaml` has `metadata.name: openai`). By changing just this variable, you can switch your application to use a completely different LLM provider.

## 2. Configure the OpenAI Component

Now we need to configure the OpenAI component with your API key:

> [!IMPORTANT]
> Open the `components/openai.yaml` file in the current folder.

This file contains the Dapr component configuration for OpenAI. Update the `apiKey` value with your actual OpenAI API key, then save the file.

The component configuration tells Dapr how to connect to OpenAI, which model to use, and other provider-specific settings.

## 3. Inspect the DaprChatClient Code

> [!NOTE]
> Open the `text_completion.py` file in the current folder.

This file demonstrates:

- How to initialize a `DaprChatClient` that uses Dapr's Conversation API
- Basic text generation with a prompt
- Using a Prompty template
- Working with explicit message objects

The key difference from the previous example is that this client doesn't communicate directly with OpenAI. Instead, it sends requests to your Dapr sidecar, which then handles the communication with the LLM provider based on your component configuration.

The architecture works as follows:
1. The `DaprChatClient` sends requests to the Dapr sidecar using the Dapr Conversation API
2. The Dapr sidecar processes these requests using the appropriate conversation component (e.g., `openai`, `echo`, etc.)
3. The conversation component handles the specifics of communicating with the LLM provider
4. Results flow back through the same path to your application

This abstraction layer allows you to switch between different LLM providers by simply changing the component configuration, without modifying your application code.

## 4. Run the Dapr Chat Client Example

Use the **terminal** window to run the text completion example with Dapr:

```bash,run
dapr run --app-id dapr-llm --resources-path ./components -- python text_completion.py
```

Notice that the command includes:
- `--app-id`: Identifies your application to Dapr
- `--resources-path`: Tells Dapr where to find your component configurations
- The Python file to execute

## 5. Expected Output

You should see output similar to this:

```
== APP == Response:  Lassie is one of the most famous dogs in popular culture. She was a fictional Rough Collie character that first appeared in a 1940 novel and later in multiple films and TV series. Lassie was known for her intelligence, loyalty, and her ability to save humans from various dangers.

== APP == Response with prompty:  My name is Claude, an AI assistant created by Anthropic.

== APP == Response with user input:  Hello! How can I help you today?
```

The exact responses may vary, but you should see three different responses similar to the direct OpenAI client example.

## 6. Benefits of the Dapr Approach

Using the Dapr Conversation API instead of calling LLMs directly offers several advantages:

1. **Provider Flexibility**: Switch between different LLM providers (OpenAI, Anthropic, Azure, etc.) by simply changing component configuration, without modifying your code.

2. **Caching**: Dapr can cache responses for identical prompts, reducing costs and latency.

3. **PII Obfuscation**: Personal identifiable information (such as phone number, email address, social security number, etc) can be automatically removed from prompts and responses.

4. **Resiliency**: Built-in or custom defined retry policies, timeouts, and circuit breakers make your applications more robust against LLM service outages.

5. **Tracing**: Dapr's observability features help you monitor and debug LLM interactions.

6. **Secret Management**: API keys can be securely retrieved through Dapr's secret store rather than in application code.

## 7. Try a Different Component (Optional)

If you want to see the provider flexibility in action, you can try using the Echo component instead:

1. Create a new `.env` file with the following content:

```bash,run
cat > .env << EOF
DAPR_LLM_COMPONENT_DEFAULT=echo
EOF
```

3. Run the application again:

```bash,run
dapr run --app-id dapr-llm --resources-path ./components -- python text_completion.py
```

With the echo component, you'll see that your prompts are simply echoed back, demonstrating how you can test your application without a real LLM call or code changes.

In the next challenge, you'll learn how to create agents that can call tools to interact with external systems. 