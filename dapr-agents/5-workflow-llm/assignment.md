In this challenge, you'll use a Dapr workflow that executes LLM calls in a deterministic durable sequence.

## 1. Introduction to Workflows

Workflows are structured processes where LLMs and tools collaborate in a predefined sequence to accomplish complex tasks. Unlike fully autonomous agents that make all decisions independently, Workflows provide a balance of:

- Structure and predictability from the workflow definition
- Intelligence and flexibility from the LLM agents within the workflow
- Reliability and durability from Dapr's workflow engine

This approach is particularly suitable for business-critical applications where you need both the intelligence of LLMs and the reliability of traditional software.

## 2. Examine the Workflow Code

Open the `04_workflow_llm.py` file in the **Editor** window to examine the code.

The workflow generates a short outline for the given topic using an LLM, then uses that outline to produce a short blog post. Both steps run as durable activities, so the workflow can restart without repeating completed LLM calls.

## 3. Run the Workflow

Use the **Terminal** window to create and activate a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

Run the workflow with Dapr by using the **Terminal** window:

```bash,run
dapr run --app-id workflow-llms --resources-path resources -- python 04_workflow_llm.py
```

## 4. Observe the Workflow Execution

> [!NOTE]
> It will take a couple of seconds for the result to appear.

The **Terminal** window will show logs similar to this:

```text,nocopy
 Final Blog Post:
"results=[LLMChatCandidate(message=AssistantMessage(content='**Understanding AI Agents: The Future of Intelligent Assistance**  \\n\\nArtificial intelligence has become a fundamental part of our everyday lives, and at the heart of this evolution are AI agents. These intelligent systems are designed to perform specific tasks and make decisions without constant human intervention. There are several types of AI agents\u2014reactive agents that respond to stimuli, proactive agents that anticipate user needs, and autonomous agents that can operate independently. Their versatility allows them to be applied across various industries, from enhancing patient care in healthcare to streamlining financial transactions and improving customer service experiences.\\n\\nHowever, the rise of AI agents isn\u2019t without its challenges. Ethical considerations play a crucial role, with concerns around bias, accountability, and transparency at the forefront. As we look to the future, advancements in AI technology will not only enhance the capabilities of these agents but also necessitate ongoing discussions about their societal impacts. As we embrace these innovative tools, fostering a responsible approach to AI development will ensure that these agents serve all of humanity effectively and equitably. Let\u2019s continue to explore this fascinating landscape together!', role='assistant'), finish_reason='stop', index=None, logprobs=None)] metadata={'provider': 'dapr', 'id': None, 'model': 'llm-provider', 'object': 'chat.completion', 'usage': {'total_tokens': '-1'}, 'created': 1773397591}"
```

## 5. How this works

1. The workflow first performs an LLM-backed activity that generates an outline from the topic. This activity uses a direct LLM call, optionally with schema validation, for predictable and validated output.
2. The resulting outline is passed to a second LLM-backed activity, which uses the LLM to generate the final blog post. This output is returned as the result of the workflow.

---

In this challenge you've learned how to use a Dapr workflow to chain together multiple AI tasks. In the next challenge, you'll learn how to build systems with multiple collaborating agents using a workflow.