## Welcome

Welcome to the Dapr Workflow with .NET Aspire learning track! In the upcoming challenges you'll build the **USS Enterprise Diagnostics** application: a Dapr Workflow that fans out to three subsystem activities in parallel, aggregates the results into a prioritized report, and conditionally notifies the bridge. Along the way you'll scaffold an Aspire solution, add Dapr Workflow dependencies, wire up the Dapr Redis state store, and use the Diagrid Dev Dashboard to inspect workflow instances. By the end of the track you have ran a Dapr Workflow with Aspire and inspected the workflow state in detail.

> [!NOTE]
> This learning track does not explain the Dapr Workflow concepts and patterns, but is focused on building a workflow using .NET and Aspire from scratch. To learn the workflow concepts & patterns follow the **Dapr Workflow - Use durable execution to build reliable applications** track.

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

---

Great, your environment is now ready! In the next challenge you'll scaffold a new Aspire solution, pin its dashboard to fixed ports so it's reachable in this sandbox environment, and add the NuGet packages required for Dapr & Dapr Workflow.
