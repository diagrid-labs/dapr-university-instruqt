# Using LLM Clients in Dapr Agents

In this challenge, you'll explore how to use Dapr Agents to interact with Large Language Models. The ability to communicate with LLMs is a foundational component of intelligent agents, enabling them to process natural language, reason about information, and generate human-like responses. Dapr Agents provides templating capabilities and structured schema interactions that allow your agents to work with different LLM providers without major code changes.

## 1. Configure your OpenAI API key

To work with LLMs, you first need to sign up with an LLM provider and obtain an API key. Throughout this tutorial, we'll be using OpenAI's models, but Dapr Agents supports multiple providers. If you wish to use a different provider, you can explore the configuration options in the Dapr Agents quickstarts.

You can get an OpenAI API key by signing up at [OpenAI](https://platform.openai.com/signup).

> [!IMPORTANT]
> Open the `.env` file in the current folder and update the `OPENAI_API_KEY` value with your actual OpenAI API key.

The API key is required for the examples to communicate with OpenAI's services.

## 2. Text Completion Example

### 2.1. Inspect the text completion code

Open the `text_completion.py` file in the current folder.

This file demonstrates different ways to interact with an LLM:

- A basic chat completion that sends a simple string prompt and gets a response
- Chat completion using a Prompty file that provides structured templating for more complex prompts
- Chat completion with an explicit user message object that allows more control over the conversation

The `OpenAIChatClient` handles the details of communicating with OpenAI's API, including authentication, request formatting, and response parsing.

### 2.2. Run the text completion example

Use the **terminal** window to run create a virtual environment:

```bash,run
python3 -m venv .venv
source .venv/bin/activate
```

Use the **terminal** window to install the dependencies:

```bash,run
pip install -r requirements.txt
```

Use the **terminal** window to run the text completion example:

```bash,run
python3 text_completion.py
```

### 2.3. Expected output

You should see output similar to this:

```text,nocopy
Response: Lassie is a famous dog known for her intelligence and heroism in the long-running TV series and films. Other famous dogs include Rin Tin Tin, Hachiko, and Balto.

Response with prompty: My name is Claude. I'm an AI assistant created by Anthropic to be helpful, harmless, and honest.

Response with user input: Hello! It's nice to meet you. How can I assist you today?
```

The exact responses may vary, but you should see three different responses to the three different prompting approaches. This demonstrates how you can interact with LLMs in varying levels of complexity depending on your application's needs.

## 3. Structured Completion Example

### 3.1. Inspect the structured completion code

Open the `structured_completion.py` file in the current folder.

This file demonstrates a powerful capability of modern LLMs - generating structured data according to a schema:

- It defines a Pydantic model (`Dog`) that specifies the exact structure and data types we expect
- It uses the `response_format` parameter to instruct the LLM to return data matching our model
- It processes the response as a typed object rather than free-form text

This approach solves one of the major challenges in working with LLMs: getting consistent, predictable outputs that can be reliably used in downstream processing.

### 3.2. Run the structured completion example

Use the **terminal** window to run the structured completion example:

```bash,run
python3 structured_completion.py
```

### 3.3. Expected output

You should see a structured JSON response similar to this:

```json,nocopy
{
  "name": "Hachiko",
  "breed": "Akita",
  "reason": "Known for his remarkable loyalty, waiting for his deceased owner at a train station for nine years until his own death"
}
```

Your specific output may feature a different famous dog, but it will follow the structure defined in the `Dog` model with name, breed, and reason fields. This demonstrates how you can get reliably structured data from an LLM, making it much easier to integrate LLM outputs into your applications and systems.

---

You've now learned how to make LLM basic calls with Dapr Agents and use a structured response format. In the next challenge, you'll learn how to use Dapr's Conversation API for LLM calls.
