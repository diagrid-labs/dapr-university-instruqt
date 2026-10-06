In this challenge you'll start the full Aspire stack, including the Dapr Dev Dashboard, trigger the USS Enterprise diagnostics workflow via curl, inspect the results, and explore the workflow timeline. It will take about 5 minutes to run through all the steps.

This challenge uses 2 terminal windows:

- *Aspire Terminal*, for running the `aspire run` command
- *Curl Terminal*, for running curl commands to start the workflow

> [!IMPORTANT]
> When you use the `run` button on shell commands in the instructions, select the appropriate terminal from the dropdown that will appear.

Ensure that all *Terminal* paths are currently in `EnterpriseDiagnostics/`.

## 1. Start Aspire

1. Start Aspire using the *Aspire Terminal*:

```shell,run,copy
aspire run
```

2. Switch to the *Aspire* tab and wait until all resources are **Running**. Next to the `apiservice` and its Dapr sidecar you'll see the `dapr-dev-dashboard` resource, which runs the Dapr Dev Dashboard.

## 2. Open the Dapr Dev Dashboard

Open the *Dapr Dev Dashboard* tab to show the dashboard, and navigate to the *Workflows* page.

## 3. Start a workflow with curl

Start a new workflow execution by running this curl command in the *Curl Terminal*:

```shell,run,copy
curl -k -X POST http://localhost:5411/start -H "Content-Type: application/json" -d '{"id":"mission-001","starDate":"41153.7"}'
```

The response returns the `instanceId`:

```json,nocopy
{ "instanceId": "mission-001" }
```

## 4. Inspect workflow state using the Dapr Dev Dashboard

On the *Workflows* page of the Dapr Dev Dashboard you'll see a new workflow entry with instance ID `mission-001`. On this page, all workflow executions are presented with their status, instance ID, workflow name, app ID, and start/end time.

1. Click on the instance ID of the workflow you just started to drill down to the workflow details page.

Here you'll see the input and output of the workflow, and the *Execution History* table with all the events. The most recent events are at the top.

2. In the *Execution History* table expand some of the events. For the `TaskScheduled` events you will see the input for the activity. For the `TaskCompleted` events you will see both input and output for the activity.

> [!NOTE]
> You can also use filters in the Execution History table to quickly find events or activities you want to inspect.

---

You've run the complete USS Enterprise diagnostics workflow end-to-end. Aspire orchestrates the API service containing the workflow, its Dapr sidecar, and the Dapr Dev Dashboard. Workflow state is stored in the Valkey container and you've inspected this state with the [Dapr Dev Dashboard](https://docs.diagrid.io/dapr-open-source/dapr-dev-dashboard/), an essential tool when developing Dapr workflows. This final challenge will take about 5 minutes to complete.

## Feedback and further learning

Congratulations! 🎉 You've completed the Dapr University Workflow & Aspire learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving this training!

We have more opportunities for you to learn and share knowledge:

**Try another university track**
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)
- [Make MAF agents reliable with Dapr Workflow](https://www.diagrid.io/university/ai-agents-maf)

**Try these Dapr tools**
- [Dapr Dev Dashboard](https://docs.diagrid.io/dapr-open-source/dapr-dev-dashboard/), a free & OSS companion tool for local Dapr development.
- [Dapr Ops Dashboard](https://docs.diagrid.io/dapr-open-source/dapr-ops-dashboard/), a free SaaS solution that automates the operational management of Dapr on Kubernetes.

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#ai* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.