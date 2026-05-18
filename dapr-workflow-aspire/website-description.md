# Build Dapr workflows in .NET with Aspire

Learn how to build a code-first, fault-tolerant Dapr Workflow application that runs end-to-end under .NET Aspire. In this hands-on track you'll scaffold a fresh Aspire solution, wire up Dapr Workflow as an Aspire resource, and use the Diagrid Dev Dashboard to inspect every step of your workflow as it runs locally.

## What you'll build

The **USS Enterprise Diagnostics** application — a Dapr Workflow application that fans out to three subsystem activities in parallel, aggregates the results into a prioritized report, and conditionally notifies the bridge when the situation is urgent. Everything starts with a single `aspire run`.

## What you'll learn

- How Dapr and .NET Aspire complement each other when building distributed applications.
- How to scaffold a new Aspire solution and add the NuGet packages required for Dapr Workflow.
- How to define a Dapr Workflow that uses the fan-out / fan-in pattern, with multiple parallel activities and conditional follow-up.
- How to configure Dapr state store components so workflow state is persisted across runs.
- How to register Dapr Workflow as an Aspire resource alongside the API service and its Dapr sidecar.
- How to trigger workflows via HTTP and inspect their state, execution history, and activity inputs/outputs in the Diagrid Dev Dashboard.

## Supported language

.NET

## Prerequisites

Familiarity with C# and basic .NET tooling is recommended. The sandbox comes preconfigured with Docker, the .NET 10 SDK, and Dapr — you'll install the Aspire CLI during the first challenge.
