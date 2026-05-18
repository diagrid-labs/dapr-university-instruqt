In this challenge you'll start the full Aspire stack, run the Diagrid Dev Dashboard, trigger the USS Enterprise diagnostics workflow via curl, inspect the results, and explore the workflow timeline.

This challenge uses 3 terminal windows:

- *Aspire Terminal*, for running the `aspire run` command
- *Diagrid Terminal*, for running the docker command to start the Diagrid Dev Dashboard
- *Curl Terminal*, for running curl commands to start the workflow

> [!IMPORTANT]
> When you use the `run` button on shell commands in the instructions, select the appropriate terminal from the dropdown that will appear.

Ensure that all *Terminal* paths are currently in `EnterpriseDiagnostics/`.

## 1. Start Aspire

1. Start Aspire using the *Aspire Terminal*:

```shell,run,copy
aspire run
```

2. Switch to the *Aspire* tab and wait until all resources are **Running**.

## 2. Start the Diagrid Dev Dashboard

1. Run the following command in the *Diagrid Terminal* to start the Diagrid Dev Dashboard:

```shell,copy,run
docker run -p 18080:8080 \
 -v ./EnterpriseDiagnostics.AppHost/Resources/dapr/diagrid-dashboard-components/diagrid-dashboard-state.yaml:/app/components/custom_state.yaml \
 -e COMPONENT_FILE=/app/components/custom_state.yaml \
 ghcr.io/diagridio/diagrid-dashboard:latest
 ```

> [!NOTE]
> When doing development on your local machine, the Diagrid Dev Dashboard can be added to Aspire via the [Diagrid Dev Dashboard Aspire integration](https://github.com/diagrid-labs/dashboard-aspire/tree/main/). At the moment, this integration is not yet working in this sandbox environment, and therefore requires starting manually.

2. Open the *Diagrid Dev Dashboard* tab, to show the dashboard and navigate to the *Observe* > *Workflows* page.

## 3. Start a workflow with curl

Start a new workflow execution by running this curl command in the *Curl Terminal*:

```shell,run,copy
curl -k -X POST http://localhost:5411/start -H "Content-Type: application/json" -d '{"id":"mission-001","starDate":"41153.7"}'
```

The response returns the `instanceId`:

```json,nocopy
{ "instanceId": "mission-001" }
```

## 5. Inspect workflow state using the Diagrid Dev Dashboard

In the *Workflow Executions* page on the Diagrid Dev Dashboard you'll see a new workflow entry. On this page, all workflow executions are presented with their status, instance ID, workflow name, app ID, start/end time, and duration (the clock icon).

1. Click on the instance ID of the workflow you just started to drill down to the *Workflow Execution Details* page.

Here you'll see the input and output of the workflow, and the *Execution History* table with all the events. The most recent events are at the top.

2. In the *Execution History* table expand some of the events. For the `TaskScheduled` events you will see the input for the activity. For the `TaskCompleted` events you will see both input and output for the activity.

> [!NOTE]
> You can also use filters in the Execution History table to quickly find events or activities you want to inspect.

---

You've run the complete USS Enterprise diagnostics workflow end-to-end. Aspire orchestrates the API service containing the workflow and its Dapr sidecar. Workflow state is stored in the `dapr_redis` container and you've inspected this state with the [Diagrid Dev Dashboard](https://docs.diagrid.io/develop/local-development/dev-dashboard), an essential tool when developing Dapr workflows.

## Feedback and further learning

Congratulations! 🎉 You've completed the Dapr University Workflow & Aspire learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving this training!

We have more opportunities for you to learn and share knowledge:

- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of other developers share knowledge about Dapr. There are dedicated channels *#workflow* and *#dotnet* channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.
- Try the [Catalyst 101](https://www.diagrid.io/dapr-university/catalyst-101) learning track to learn how Catalyst can make your workflow and agentic applications more reliable.
