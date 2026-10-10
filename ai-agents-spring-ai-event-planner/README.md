# Name

Making Spring AI agents durable with Dapr Workflow

## Url

ai-agents-spring-ai-event-planner

## Teaser

Run a Spring AI agent that plans an event in three steps, watch it crash on purpose mid-plan, then restart it and watch it finish the plan without repeating any completed step.

Languages: Java. Duration: 30 min. Requires a free Diagrid Catalyst account. No LLM API key needed.

## Time limit (minutes)

30

## Description

Spring AI gives you a `ChatClient` and `@Tool` beans to build an agent. On its own, a crash mid-call throws away everything: the conversation, the tool results, and any partial plan. In this self-paced track you'll see how adding one starter dependency, `diagrid-spring-ai-starter`, makes every `ChatClient.call()` durable, with no durability code in the agent itself.

You'll work with an **Event Planner** agent that calls three tools in sequence to plan an event. The second tool deliberately crashes the process the first time it runs. You'll restart the app and watch it pick up exactly where it left off.

In this self-paced track, you'll learn:
- How `diagrid-spring-ai-starter` turns a `ChatClient.call()` into a Dapr Workflow with no application code changes.
- Why a durable activity needs to be idempotent, and why side-effect-free tools make that easy.
- How to run the agent on Diagrid Catalyst and trigger it over HTTP.
- How a real process crash resumes automatically, without re-triggering the request or re-running completed steps.

You'll probably need around 25 minutes to complete the 4 challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
