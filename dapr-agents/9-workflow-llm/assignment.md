In this challenge, you'll use a Dapr workflow that executes LLM calls in a deterministic durable sequence.

## 1. Introduction to Workflows

Workflows are structured processes where LLMs and tools collaborate in a predefined sequence to accomplish complex tasks. Unlike fully autonomous agents that make all decisions independently, Workflows provide a balance of:

- Structure and predictability from the workflow definition
- Intelligence and flexibility from the LLM agents within the workflow
- Reliability and durability from Dapr's workflow engine

This approach is particularly suitable for business-critical applications where you need both the intelligence of LLMs and the reliability of traditional software.

## Workflows vs. Autonomous Agents

| Aspect | Workflows | Fully Autonomous Agents |
|--------|-------------------|-------------------------|
| Control | Developer-defined process flow | Agent determines next steps |
| Predictability | Higher | Lower |
| Flexibility | Fixed overall structure, flexible within steps | Completely flexible |
| Reliability | Very high (workflow engine guarantees) | Depends on agent implementation |
| Complexity | Simpler to reason about | Harder to debug and understand |
| Use Cases | Business processes, regulated domains | Open-ended research, creative tasks |

## 2. Examine the Workflow Code

Open the `08_workflow_llm.py` file in the **Editor** window to examine the code.

The workflow generates a short outline for the given topic using an LLM, then uses that outline to produce a short blog post. Both steps run as durable activities, so the workflow can restart without repeating completed LLM calls.

### How this works

1. The workflow first performs an LLM-backed activity that generates an outline from the topic. This activity is decorated with `@llm_activity`, a Dapr Agents annotation that simplifies workflow activities by automatically wiring in the LLM client and performing the model invocation for you.
2. The resulting outline is passed to a second `@llm_activity`-decorated activity, which uses the LLM to generate the final blog post. This output is returned as the result of the workflow.

## 3. Run the Workflow

Use the **Terminal** window to create and activate a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```
Run the workflow with Dapr by using the **Terminal** window:

```bash,run
dapr run --app-id workflow-llms --resources-path resources -- python 08_workflow_llm.py
```

## 4. Observe the Workflow Execution

Watch the output in your terminal. You should see something like:

```text,nocopy
== APP == ✅ Final Blog Post:
== APP == "AI agents are computer programs or systems designed to perceive their environment, make decisions, and act autonomously to achieve specific goals. At their core, AI agents are the \u201cdoers\u201d of the AI world, handling everything from navigating a self-driving car to helping you find the best route on your GPS. There are several types of AI agents, each with different levels of complexity. Simple reflex agents act based solely on current inputs, while model-based agents use internal representations of the world to inform their actions. Goal-based agents go a step further by aiming for specific objectives, and utility-based agents weigh the best choices according to preferences or rewards. Learning agents are the most dynamic\u2014they adapt and improve their behavior over time based on new experiences.\n\nAn AI agent\u2019s magic lies in three key components: perception (sensing what\u2019s going on), reasoning (figuring out what to do), and action (actually doing it). These agents are everywhere in real-world scenarios\u2014from virtual assistants recommending your next playlist, to robots assembling cars, and even in healthcare systems predicting patient needs. However, building reliable AI agents isn\u2019t without challenges. They must handle uncertainty, adapt to changing environments, and make ethical decisions. Looking ahead, trends like explainable AI, improved learning methods, and collaborative multi-agent systems are shaping smarter, more trustworthy agents that will make our digital future even brighter."
```

---

In this challenge you've learned how to use a Dapr workflow to chain together multiple AI tasks. In the next challenge, you'll learn how to build systems with multiple collaborating agents using a workflow.