# Name

Making LangGraph agents durable with Dapr Workflow

## Url

ai-agents-langgraph

## Teaser

Run a LangGraph agent as a durable Dapr Workflow. Then crash it mid-run and watch it resume from a checkpoint in Redis, without re-running the steps that already completed.

Languages: Python. Duration: 30 min. Requires an OpenAI API key.

## Time limit (minutes)

30

## Description

LangGraph gives you the structure to build an agent as a state machine: nodes, edges, and shared state. What it doesn't give you is durability. Kill the process mid-run and everything in memory is gone. In this self-paced track you'll see how **Dapr Workflow** turns a LangGraph graph into a durable, crash-proof application.

You'll work with **Schedule Planner**, a LangGraph agent that checks venue availability using a `check_availability` tool. It runs as a Dapr Workflow via the `diagrid[langgraph]` SDK.

In this self-paced track, you'll learn:
- What LangGraph is and how it structures an agent as nodes, edges, and state.
- How `DaprWorkflowGraphRunner` wraps a compiled LangGraph graph so each node executes as a checkpointed Dapr Workflow activity.
- How to trigger the agent over HTTP and watch workflow events as it runs.
- How to inspect checkpointed workflow state directly in Redis.
- How a mid-run crash resumes from durable state, without re-executing completed nodes.

You'll probably need around 25 minutes to complete the 4 challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
