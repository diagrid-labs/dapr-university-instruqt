In this challenge, you'll build a Lord of the Rings-themed workflow that chains together multiple AI tasks to generate creative content.

### Prerequisite

> [!IMPORTANT]
> Open the `.env` file in the current folder and validate the `OPENAI_API_KEY` value is present. If it is not present, update it with your actual OpenAI API key.

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

Open the `workflow_dapr_agent.py` file in the **Editor** window:

```python,nocopy
from dapr_agents.workflow import WorkflowApp, workflow, task
from dapr.ext.workflow import DaprWorkflowContext
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Define Workflow logic
@workflow(name="task_chain_workflow")
def task_chain_workflow(ctx: DaprWorkflowContext):
    character = yield ctx.call_activity(get_character)
    print(f"Character: {character}")
    line = yield ctx.call_activity(get_line, input={"character": character})
    print(f"Line: {line}")
    return line

@task(
    description="""
    Pick a random character from The Lord of the Rings\n
    and respond with the character's name only
"""
)
def get_character() -> str:
    pass

@task(
    description="What is a famous line by {character}",
)
def get_line(character: str) -> str:
    print(f"Character: {character}")
    pass

if __name__ == "__main__":
    wfapp = WorkflowApp()
    results = wfapp.run_and_monitor_workflow_sync(task_chain_workflow)
    print(f"Results: {results}")
```

Notice that this workflow:

1. First calls the `get_character` task to generate a Lord of the Rings character
2. Then passes that character to the `get_line` task to create a famous quote
3. Finally returns the generated line as the workflow result

## Understand the Task Definitions

The workflow uses two AI-powered tasks:

1. `get_character`: Generates a random Lord of the Rings character
    - Has a description that guides the LLM
    - Returns a string with just the character name
2. `get_line`: Creates a famous quote for the character
    - Receives the character name as input
    - Uses the character to generate an appropriate quote

Notice that the task implementations are empty (`pass`). The LLM provides the actual implementation at runtime based on the description.

## 3. Run the Workflow

Use the **Terminal** window to create a virtual environment:

```bash,run
python3 -m venv .venv
source .venv/bin/activate
```
Use the **Terminal** window to install the dependencies:

```bash,run
pip install -r requirements.txt
```

Run the workflow with Dapr by using the **Terminal** window:

```bash,run
dapr run --app-id dapr-agent-wf --resources-path components/ -- python workflow_dapr_agent.py
```

## 4. Observe the Workflow Execution

Watch the output in your terminal. You should see something like:

```
== APP == Character: Gandalf
== APP == Character: Gandalf
== APP == Line: "A wizard is never late, nor is he early. He arrives precisely when he means to."
== APP == Results: "A wizard is never late, nor is he early. He arrives precisely when he means to."
```

The workflow:

1. First generates a character name
2. Then creates a famous quote for that character
3. Finally returns the completed quote

## 5. Task Types in Workflows

Dapr Agents supports different types of tasks within workflows allowing you to coordinate LLM interactions at different granularity.

### Prompt Tasks

Tasks created from a prompt that use LLM's reasoning capabilities (as in the current example)

```python,nocopy
@task(
    description="""
    Pick a random character from The Lord of the Rings\n
    and respond with the character's name only
""" )
def get_character() -> str:
    pass
```

### Agent Tasks

Tasks that are based on agents with or without tools giving more flexibility on what a task can do:

```python,nocopy
@task(agent=custom_agent, description="Retrieve stock data for {ticker}")
def get_stock_data(ticker: str) -> dict:
    """Uses tools to get real data"""
    # In the implementation, you would use tools like:
    # result = stock_api_tool(ticker=ticker)
    pass
```

## 6. Workflow Patterns to Explore

Here are a few common patterns and code extracts. To see full working pattern examples, check out this repo: [https://github.com/diagrid-labs/building-effective-dapr-agents](https://github.com/diagrid-labs/building-effective-dapr-agents)

### Sequential Workflows

Tasks execute one after another:

```python,nocopy
@workflow(name='sequential_workflow')
def sequential_process(ctx: DaprWorkflowContext, input_data: str):
    result1 = yield ctx.call_activity(task1, input=input_data)
    result2 = yield ctx.call_activity(task2, input=result1)
    return result2
```

### Parallel Workflows

Multiple tasks execute simultaneously:

```python,nocopy
@workflow(name='parallel_workflow')
def parallel_process(ctx: DaprWorkflowContext, input_data: str):
    # Execute tasks in parallel
    task1_result = ctx.call_activity(task1, input=input_data)
    task2_result = ctx.call_activity(task2, input=input_data)
    
    # Wait for all tasks to complete
    results = yield ctx.when_all([task1_result, task2_result])
    
    # Process the combined results
    final_result = yield ctx.call_activity(combine_results, input=results)
    return final_result
```

### Conditional Workflows

Decision points in the workflow:

```python,nocopy
@workflow(name='conditional_workflow')
def approval_process(ctx: DaprWorkflowContext, request: dict):
    # Analyze the request
    analysis = yield ctx.call_activity(analyze_request, input=request)
    
    # Make a decision based on the analysis
    if analysis["risk_score"] < 50:
        # Low risk - automatic approval
        result = yield ctx.call_activity(approve_request, input=request)
    else:
        # High risk - human review
        result = yield ctx.call_activity(human_review, input=request)
    
    return result
```

### Human-in-the-Loop (HITL) and Timeout

A human approval step with a 24-hour timeout before continuing the workflow:

```python,nocopy
@workflow(name='sequential_workflow')
def sequential_process(ctx: DaprWorkflowContext, input_data: str):
    result1 = yield ctx.call_activity(task1, input=input_data)
    
    # Wait for human approval or timeout
    approval_event = yield ctx.wait_for_external_event("approval_received")
    timeout_event = yield ctx.create_timer(timedelta(hours=24))
    winner = yield ctx.when_any([approval_event, timeout_event])
    if winner == timeout_event:
        return "Cancelled"
    
    # Continue as normal
    return = yield ctx.call_activity(task2, input=result1)
```

These patterns, combined with error handling, compensation, and APIs for monitoring and managing workflows are essential for long-running workflows.

---

In this challenge you've learned how to use a workflow to chain together multiple AI tasks. In the next challenge, you'll learn how to build systems with multiple collaborating agents.