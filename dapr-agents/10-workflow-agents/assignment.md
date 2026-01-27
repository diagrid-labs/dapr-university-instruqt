In this final challenge, you'll use a workflow that invokes agents as workflow activities, allowing you to orchestrate multi-step agent reasoning in a durable and deterministic way. Unlike previous challenges where activities called LLMs directly, this workflow delegates each step to an agent with tools and memory, while the workflow engine provides durability and reliable progression.

## 1. Understanding Multi-Agent Systems

Multi-agent systems consist of multiple specialized AI agents that collaborate to solve complex tasks that might be difficult for a single agent to handle. Key characteristics of such a system in Dapr Agents include:

1. **Specialized Agents**: Each agent has a specific role, personality, and set of skills
2. **Event-Driven Communication**: Agents communicate via messages through a pub/sub system
3. **Orchestration**: A coordinator manages the flow of information between agents
4. **Stateful Interactions**: The system maintains state across the conversation

This approach enables powerful collaborative problem-solving, parallel processing, and division of responsibilities among specialized agents.

## 2. Examine the Code

Use the **Editor** window to examine `09_workflow_agents.py` file.

When the workflow runs, it first delegates the request to a triage agent, which gathers customer information using tools and produces a summary. It then passes that summary to an expert agent, which generates a final recommendation. Both steps run under a durable workflow, so if the process is interrupted, it resumes from the last completed activity even though the agents themselves are not durable.

### How This Works

1. The workflow invokes each agent using activities decorated with `@agent_activity`, which handles calling the agent and returning structured output.
2. The triage activity runs first, producing a summary based on customer data and the issue description.
3. The output of the triage agent is passed into the expert agent activity to generate the final recommendation.
4. Although agents can use tools and maintain their own memory, the workflow execution is what provides durability: if interrupted, it restarts from the last completed step.

## 3. Run the Multi-Agent Workflow

Use the **Terminal** window to create a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

To use this configuration, run the following command in the **Terminal** window:

```bash,run
dapr run --app-id workflow-agents --resources-path resources -- python 09_workflow_agents.py
```

## 4. Monitor the Workflow Execution

You should see output similar to:

```text,nocopy
== APP == Workflow started: bc777b5415ed43678b86ccaa0c9ac194
== APP == user:
== APP == customer: alice
== APP == issue: Unable to access dashboard after recent update
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Triage Agent(assistant):
== APP == Function name: GetCustomerInfo (Call Id: call_B4ro54xYfMps7RUH02T5xXCX)
== APP == Arguments: {"customer_name":"alice"}
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == GetCustomerInfo(tool) (Id: call_B4ro54xYfMps7RUH02T5xXCX):
== APP == Customer: Alice, Premium Plan, 5 active services
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Triage Agent(assistant):
== APP == Triage Summary:
== APP == 
== APP == - Customer Name: Alice
== APP == - Account: Premium Plan, 5 active services
== APP == - Reported Issue: Unable to access dashboard after recent update
== APP == 
== APP == Is there any additional detail regarding the error message, browser, or device Alice is using? This will help prepare a more comprehensive case for technical support.
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Triage result: Triage Summary:
== APP == 
== APP == - Customer Name: Alice
== APP == - Account: Premium Plan, 5 active services
== APP == - Reported Issue: Unable to access dashboard after recent update
== APP == 
== APP == Is there any additional detail regarding the error message, browser, or device Alice is using? This will help prepare a more comprehensive case for technical support.
== APP == user:
== APP == Triage Summary:
== APP == 
== APP == - Customer Name: Alice
== APP == - Account: Premium Plan, 5 active services
== APP == - Reported Issue: Unable to access dashboard after recent update
== APP == 
== APP == Is there any additional detail regarding the error message, browser, or device Alice is using? This will help prepare a more comprehensive case for technical support.
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Expert Agent(assistant):
== APP == Thank you for compiling the triage summary.
== APP == 
== APP == **Recommendation:**  
== APP == Yes, collecting more specific information will help expedite and accurately resolve Alice's issue. Please reach out to Alice and request the following details:
== APP == 
== APP == 1. **Exact Error Message:**  
== APP ==    What does she see on the screen when trying to access the dashboard (e.g., error code, blank page, spinning loader)?
== APP == 
== APP == 2. **Browser Information:**  
== APP ==    Which browser(s) is she using (e.g., Chrome, Firefox, Edge, Safari), and what are the versions? Has she tried clearing cookies/cache or using an incognito/private window?
== APP == 
== APP == 3. **Device Type:**  
== APP ==    Is she accessing from a desktop, laptop, tablet, or mobile device? What operating system and version is she using?
== APP == 
== APP == 4. **Network Status:**  
== APP ==    Is she on a corporate or personal network? Has she tried accessing via another network or device?
== APP == 
== APP == 5. **Timestamp and Frequency:**  
== APP ==    When did the issue start, and is it persistent or intermittent? Does it happen with all 5 active services or just one?
== APP == 
== APP == Having these details will allow technical support to better diagnose the problem and provide a faster resolution. 
== APP == 
== APP == Let me know once you have this information or if you need a template to request it from Alice.
== APP == 
== APP == --------------------------------------------------------------------------------
== APP == 
== APP == Triage result: Triage Summary:
== APP == 
== APP == - Customer Name: Alice
== APP == - Account: Premium Plan, 5 active services
== APP == - Reported Issue: Unable to access dashboard after recent update
== APP == 
== APP == Is there any additional detail regarding the error message, browser, or device Alice is using? This will help prepare a more comprehensive case for technical support.
== APP == Recommendation: Thank you for compiling the triage summary.
== APP == 
== APP == **Recommendation:**  
== APP == Yes, collecting more specific information will help expedite and accurately resolve Alice's issue. Please reach out to Alice and request the following details:
== APP == 
== APP == 1. **Exact Error Message:**  
== APP ==    What does she see on the screen when trying to access the dashboard (e.g., error code, blank page, spinning loader)?
== APP == 
== APP == 2. **Browser Information:**  
== APP ==    Which browser(s) is she using (e.g., Chrome, Firefox, Edge, Safari), and what are the versions? Has she tried clearing cookies/cache or using an incognito/private window?
== APP == 
== APP == 3. **Device Type:**  
== APP ==    Is she accessing from a desktop, laptop, tablet, or mobile device? What operating system and version is she using?
== APP == 
== APP == 4. **Network Status:**  
== APP ==    Is she on a corporate or personal network? Has she tried accessing via another network or device?
== APP == 
== APP == 5. **Timestamp and Frequency:**  
== APP ==    When did the issue start, and is it persistent or intermittent? Does it happen with all 5 active services or just one?
== APP == 
== APP == Having these details will allow technical support to better diagnose the problem and provide a faster resolution. 
== APP == 
== APP == Let me know once you have this information or if you need a template to request it from Alice.
```

## 5. When to Use Multi-Agent Systems

Multi-agent systems are particularly well-suited for:

- **Complex Problem Solving**: Tasks requiring multiple types of expertise
- **Creative Collaboration**: Generating ideas from diverse perspectives
- **Role-Playing Scenarios**: Simulating interactions between different characters
- **Debate and Deliberation**: Presenting multiple viewpoints on a topic
- **Distributed Processing**: Breaking down large tasks into parallel operations

By leveraging multiple specialized agents, you can create AI systems that tackle problems too complex for a single agent to handle effectively.

## 6. Collect your badge & provide feedback

Congratulations! 🎉 You've completed the Dapr University Dapr Agents learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving this training 🚀.

All code samples shown in this Dapr University track are available in the [Dapr Agents](https://github.com/dapr/dapr-agents/) repository in the `quickstarts` folder. Give this repo a star and clone it locally to use it as reference material for building your next Dapr Agents project.

Collect the Dapr University badge for this track by following [this link to the Holopin platform](https://holopin.io/collect/cmcnbixyg090907l820ki10nd). You'll need a GitHub account to claim the badge.

[![Dapr University Dapr Agents badge](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-agents/10-workflow-agents/Diagrid-Dapr-Uni-Agents_x500.png?raw=true)](https://holopin.io/collect/cmcnbixyg090907l820ki10nd)

If you have any questions or feedback about this track, you can let us know in the *#dapr-agents* channel of the [Dapr Discord server](https://bit.ly/dapr-discord).

## Next Steps

Now that you've completed the Dapr Agents learning track, here are some recommended next steps:

- [Dapr University: Running Dapr applications with Diagrid Catalyst]([Running Dapr applications with Diagrid Catalyst](https://www.diagrid.io/dapr-university#catalyst-101))
- Try [Diagrid Catalyst](https://www.diagrid.io/catalyst), the enterprise platform for workflow orchestration, service discovery and pub/sub, powered by Dapr. Build apps and AI agents that are compliant, secure and failure-proof.