# Building Agents with ReAct Pattern

In this tutorial, you'll learn how to create AI agents using the ReAct pattern in Dapr Agents. You'll explore how this pattern combines reasoning and action to solve complex tasks through an explicit, step-by-step problem-solving approach.

## Understanding Agents
As we've seen in previous tutorials, agents in Dapr Agents combine three key components:

1. **Instructions**: Guidance that shapes the agent's behavior and responses
2. **Tools**: Functions that extend the agent's capabilities beyond conversation
3. **Memory**: Storage that allows the agent to remember conversation history

The ReAct pattern introduces a fourth critical element:

4. **Reasoning Process**: An explicit, transparent thought process that guides decision-making

## Introduction to ReAct Agents
The ReAct (Reasoning + Action) pattern is an approach that enables agents to solve complex problems by making their thinking process explicit. A ReAct agent follows this cycle:

1. **Thought**: The agent reasons about the problem and decides what to do next
2. **Action**: The agent selects and uses a tool based on its reasoning
3. **Observation**: The agent observes the result of the tool execution
4. **Repeat**: The agent continues this cycle until it reaches a conclusion

Unlike standard tool calling agents that hide their reasoning process, ReAct agents show their step-by-step thinking, making it easier to understand and debug their decision-making.

## Comparing Tool Calling and ReAct Agents

> [!NOTE]
> Let's understand how ReAct agents differ from standard tool calling agents:

| **Aspect**           | **ToolCallAgent**                   | **ReActAgent**                            |
| -------------------- | ----------------------------------- | ----------------------------------------- |
| Reasoning Process    | Hidden (internal to the LLM)        | Explicit and visible                      |
| Problem Complexity   | Best for straightforward tasks      | Excels at multi-step, complex problems    |
| Output Format        | Direct answers                      | Thought → Action → Observation → Answer   |
| Self-correction      | Limited                             | Can revise approach based on observations |
| Tool Calling Trigger | LLM emits structured tool_calls (OpenAI-style)	| LLM emits inline JSON Action: block in response text|
| Best Use Case        | Simple assistants and utility tasks | Complex problem solving with tool use     |

While tool calling agents are ideal for simple, direct tasks, ReAct agents shine when tackling problems that require multiple steps and careful reasoning.

### Prerequisite

> [!IMPORTANT]
> Open the `.env` file in the current folder and validate the `OPENAI_API_KEY` value is present. If it is not present, update with your actual OpenAI API key.

The API key is required for the examples to communicate with OpenAI's services.

## Exploring the ReAct Example

Let's explore the example file to understand how a ReAct agent works in practice.

Open the `reason_act.py` file to see a simple implementation of a ReAct agent:

```python
import asyncio
from dapr_agents import tool, ReActAgent
from dotenv import load_dotenv

load_dotenv()

@tool
def search_weather(city: str) -> str:
    """Get weather information for a city."""
    weather_data = {"london": "rainy", "paris": "sunny"}
    return weather_data.get(city.lower(), "Unknown")

@tool
def get_activities(weather: str) -> str:
    """Get activity recommendations."""
    activities = {"rainy": "Visit museums", "sunny": "Go hiking"}
    return activities.get(weather.lower(), "Stay comfortable")

async def main():
    react_agent = ReActAgent(
        name="TravelAgent",
        role="Travel Assistant",
        instructions=["Check weather, then suggest activities"],
        tools=[search_weather, get_activities],
    )

    result = await react_agent.run("What should I do in London today?")
    if result:
        print("Result:", result)

if __name__ == "__main__":
    asyncio.run(main())
```

Notice how this agent is created using the `ReActAgent` class, which implements the ReAct pattern. Alternatively we could use `Agent` factory class and explicitly set the `pattern` field to `react`.

## Understanding the ReAct Implementation
While this is a simple example, behind the scenes, the ReAct agent uses a sophisticated implementation:

1. The agent constructs a system prompt that guides the LLM to follow the ReAct format
2. It includes explicit instructions for generating Thought, Action, and Observation steps
3. It parses the LLM response to identify these components
4. It executes tools and incorporates results into the reasoning chain
5. It continues this process until a final answer is reached

This structured approach enables the agent to transparently work through problems step by step.

## Running the ReAct Agent

Let's run the ReAct agent to see it in action.

```bash
python reason_act.py
```

You should see output similar to:
```
user:
What should I do in London today?
Thought: I need to check the weather in London to suggest appropriate activities.
Action: {"name": "search_weather", "arguments": {"city": "London"}}
Observation: rainy
Thought: Now that I know it's rainy in London, I can suggest appropriate activities.
Action: {"name": "get_activities", "arguments": {"weather": "rainy"}}
Observation: Visit museums
Thought: I now have the information needed to provide a recommendation.
Answer: Since it's rainy in London today, I recommend visiting museums. London has many world-class museums like the British Museum, National Gallery, and Tate Modern that are perfect for a rainy day.
```

Notice how the agent:
1. First thinks about checking the weather in London
2. Uses the `search_weather` tool to find out it's rainy
3. Then thinks about suggesting appropriate activities
4. Uses the `get_activities` tool to learn that museums are recommended for rainy weather
5. Finally provides a comprehensive answer based on all the information gathered

This explicit reasoning chain makes it easy to follow the agent's decision-making process.

## How ReAct Works Behind the Scenes

1. **Prompt Engineering**: The system prompt instructs the LLM to generate Thought, Action, and Observation statements
2. **Response Parsing**: The agent parses these components from the LLM's response
3. **Tool Execution Loop**: For each Action, the agent executes the corresponding tool
4. **Contextual Updates**: Observations from tools are fed back into the reasoning process
5. **Termination Conditions**: The agent continues until it reaches a final answer or hits max iterations

This approach enables complex reasoning while maintaining traceability.

## Benefits of the ReAct Pattern

> [!NOTE]
> The ReAct pattern offers several key advantages:

1. **Transparency**: The agent's reasoning is visible, making it easier to understand and debug
2. **Multi-step reasoning**: Ideal for problems that require breaking down into multiple steps
3. **Self-correction**: Agents can adjust their approach based on intermediate results
4. **Explainability**: Users can see how and why the agent reached its conclusions
5. **Complex problem-solving**: Can tackle tasks too complex for standard agents

These advantages make ReAct agents particularly valuable for tasks that require careful reasoning, fact-checking, or multi-stage problem-solving.


## When to Use ReAct Agents

ReAct agents are particularly valuable for:

- Complex research tasks requiring multiple queries
- Decision-making processes with multiple factors
- Procedural tasks with interdependent steps
- Problems that benefit from a chain of reasoning
- Situations where explaining the reasoning process is important

For simpler tasks where a direct answer is sufficient, the standard tool calling agent may be more efficient.
