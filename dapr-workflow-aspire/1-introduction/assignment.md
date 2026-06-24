Welcome to the *Dapr Workflow with .NET Aspire* learning track! In the upcoming challenges you'll build the **USS Enterprise Diagnostics** application. This application performs diagnostics on the USS Enterprise star ship. It uses Dapr Workflow to fan out to three star ship subsystem activities in parallel, aggregates the results into a prioritized report, and conditionally notifies the bridge. Along the way you'll scaffold an Aspire solution, add Dapr Workflow dependencies, wire up a Redis state store, and use the Diagrid Dev Dashboard to inspect workflow instances. By the end of the track you have ran a Dapr Workflow application with Aspire and inspected the workflow state in detail. This first challenge will take about 5 minutes to complete.

![workflow-app-aspire.png](https://play.instruqt.com/assets/tracks/kyfkrd3ggejg/c04838dd7ad3f33b4786f69d276aa771/assets/workflow-app-aspire.png)

> [!NOTE]
> This learning track does not explain the Dapr Workflow concepts and patterns but is focussed on building a workflow using .NET and Aspire from scratch. To learn the workflow concepts & patterns follow the **[Dapr Workflow - Use durable execution to build reliable applications](https://www.diagrid.io/university/dapr-workflow)** track.

## Why Dapr and Aspire?

Dapr and .NET Aspire are highly complementary technologies that together provide a great developer experience for building distributed applications:

- **Local development**: Aspire orchestrates all the resources your application needs (services, containers, Dapr sidecars, state stores) from a single AppHost project, so a single `aspire run` spins up the whole system with a unified dashboard for logs, traces, and metrics.
- **Decoupling from infrastructure**: Dapr's building block APIs (workflow, state, pub/sub, bindings, secrets) let your application code stay independent of the concrete infrastructure backing them. Swap the Redis state store for another supported state store without touching application code.
- **Resiliency**: Dapr Workflow provides durable, code-first orchestration with automatic retries, replay, and recovery on failure, making long-running and fault-tolerant business processes straightforward to express.
- **Graduated CNCF project**: Dapr is a graduated project in the Cloud Native Computing Foundation, signaling production maturity, a healthy open governance model, and a vendor-neutral ecosystem you can rely on.

## Prerequisites

The learning environment comes with **Docker**, the **.NET 10 SDK**, and **Dapr** already installed, so you don't need to install those yourself. The only tool still missing is the **Aspire CLI**, which you'll install now.

## Verify Dapr is initialized

Check that Dapr is initialized by running the following command in the *Terminal*:

```shell,run,copy
dapr -v
```

Only if the **Runtime version** is empty, initialize Dapr by running `dapr init`. This will install several containers that Dapr requires, including a Redis container that is used for the workflow state.

## Install the Aspire CLI

Run the install script in the *Terminal*:

```shell,run,copy
curl -sSL https://aspire.dev/install.sh | /bin/bash
```

Then reload the shell so the `aspire` command is on your `PATH`:

```shell,run,copy
source /root/.bashrc
```

Now, pin the Aspire project templates version to `13.3.5`, so they work inside this sandbox environment. The latest Aspire version does not work yet, so **don't** upgrade to `13.4.*`.

```shell,run,copy
dotnet new install Aspire.ProjectTemplates@13.3.5
```

---

Great, your environment is now ready! In the next challenge you'll scaffold a new Aspire solution, pin its dashboard to fixed ports so it's reachable in this sandbox environment, and add the NuGet packages required for Dapr & Dapr Workflow.
