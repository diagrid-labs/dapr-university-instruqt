## Name

Build Dapr workflows in .NET with Aspire

## URL

dapr-workflow-aspire

## Teaser

Build and run a code-first, fault-tolerant Dapr Workflow application end-to-end with .NET Aspire, and inspect every step with the Diagrid Dev Dashboard.

Languages: .NET. Duration: 30 min.

## Time limit (minutes)

30

## Description

This learning track shows you how to build a durable, code-first workflow application that runs end-to-end under Aspire orchestration. Across five hands-on challenges, you'll scaffold a new Aspire solution, add the Dapr Workflow NuGet packages, and configure the AppHost so a Dapr sidecar runs alongside your API service with an existing Redis state store for workflow persistence. The application you build — USS Enterprise Diagnostics — fans out to three subsystem activities in parallel, aggregates the results into a prioritized report, and conditionally notifies the bridge when the situation is urgent. You'll run the Aspire solution, trigger workflows via curl, and use the Diagrid Dev Dashboard to inspect workflow instances, their execution history, and the inputs and outputs of every activity.