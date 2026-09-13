# Making Spring AI agents durable with Dapr Workflow

Spring AI gives you a `ChatClient` and `@Tool` beans to build an agent. On its own, a crash mid-call loses everything, and a naive retry can repeat a side effect like a booking or a payment. In this hands-on track you'll see how one starter dependency makes a Spring AI agent durable, and how a caller-owned instance id makes a retry safe.

## What you'll build

You'll run a **booking agent** built with Spring AI and `diagrid-spring-ai-starter`. It commits a reservation through a deliberately slow tool. You'll crash the app while that tool is running, restart it, and re-issue the exact same request to prove it attaches to the resumed run and returns the same confirmation code instead of booking twice.

## What you'll learn

- Why a durable side-effecting tool call needs more than retry logic.
- How `diagrid-spring-ai-starter` turns a `ChatClient.call()` into a Dapr Workflow with no application code changes.
- How a caller-owned instance id lets a retry attach to an in-flight or completed run.
- How to run and inspect the agent on Diagrid Catalyst.
- How a real process kill proves completed work is not repeated on recovery.

## Supported language

Java

## Prerequisites

Familiarity with Java and Spring Boot is recommended. The sandbox comes preconfigured with JDK 21, Maven, and the Diagrid CLI. You'll need a free Diagrid Catalyst account and your own OpenAI API key.
