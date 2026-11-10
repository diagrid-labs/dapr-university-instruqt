# Making Spring AI agents durable with Dapr Workflow

Spring AI gives you a `ChatClient` and `@Tool` beans to build an agent. On its own, a crash mid-call throws away the conversation, the tool results, and any partial work. In this hands-on track you'll see how one starter dependency makes a Spring AI agent durable, with no durability code in the agent itself.

## What you'll build

You'll run an **Event Planner** agent built with Spring AI and `diagrid-spring-ai-starter`. It calls three tools in sequence to plan an event, and the second tool deliberately crashes the process the first time it runs. You'll restart the app and watch it finish the plan without repeating the steps that already completed.

## What you'll learn

- How `diagrid-spring-ai-starter` turns a `ChatClient.call()` into a Dapr Workflow with no application code changes.
- Why a durable activity needs to be idempotent, and why side-effect-free tools make that easy.
- How to run and trigger the agent on Diagrid Catalyst.
- How a real process crash resumes automatically, without re-triggering the request.

## Supported language

Java

## Prerequisites

Familiarity with Java and Spring Boot is recommended. The sandbox comes preconfigured with JDK 21, Maven, and the Diagrid CLI. You'll need a free Diagrid Catalyst account. No LLM API key is required, the agent ships with an offline model by default.
