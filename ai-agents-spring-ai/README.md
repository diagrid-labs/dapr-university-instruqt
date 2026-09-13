# Name

Making Spring AI agents durable with Dapr Workflow

## Url

ai-agents-spring-ai

## Teaser

Run a Spring AI booking agent that survives a hard crash mid-call, then kill it on purpose and prove a retry attaches to the resumed run instead of booking twice.

Languages: Java. Duration: 30 min. Requires a free Diagrid Catalyst account and an OpenAI API key.

## Time limit (minutes)

30

## Description

Spring AI gives you a `ChatClient` and `@Tool` beans to build an agent. On its own, a crash mid-call loses everything, and a naive retry risks doing the same side effect twice. In this self-paced track you'll see how adding one starter dependency, `diagrid-spring-ai-starter`, makes every `ChatClient.call()` durable, backed by Dapr Workflow.

You'll work with a **booking agent** that commits a reservation through a deliberately slow tool. You'll crash the app mid-booking, restart it, and re-issue the same request to prove it resumes instead of double-booking.

In this self-paced track, you'll learn:
- Why a durable side-effecting tool call needs more than just retry logic.
- How `diagrid-spring-ai-starter` turns a `ChatClient.call()` into a Dapr Workflow with no application code changes.
- How a caller-owned instance id lets a retry attach to an in-flight or completed run instead of starting a new one.
- How to run the agent on Diagrid Catalyst and inspect it through the dashboard.
- How a real process kill proves the booking is not repeated on recovery.

You'll probably need around 28 minutes to complete the 4 challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
