In this challenge you'll start the full Aspire stack, trigger the USS Enterprise diagnostics workflow via curl, inspect the results, and explore the workflow timeline in the Diagrid Dev Dashboard.

Ensure that the *Terminal* path is currently in `EnterpriseDiagnostics/`.

## 1. Start Aspire

1. Start Aspire using the *Aspire Terminal*:

```shell,run,copy
aspire run
```

2. Switch to the *Aspire* tab and wait until **`apiservice`**, **`cache`**, and **`diagrid-dashboard`** all show as **Running**.

## 2. Start the Diagrid Dev Dashboard

1. Run the following command in the *Diagrid Terminal* to start the Diagrid Dev Dashboard:

```shell,copy,run
docker run -p 18080:8080 \
 -v ./EnterpriseDiagnostics.AppHost/Resources/dapr/diagrid-dashboard-components/diagrid-dashboard-state.yaml:/app/components/custom_state.yaml \
 -e COMPONENT_FILE=/app/components/custom_state.yaml \
 ghcr.io/diagridio/diagrid-dashboard:latest
 ```

2. Open the Diagrid Dev Dashboar tab, to show the dashboard and navigate to the *Observe* > *Workflows* page.

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

In the *Workflow Executions* page on the dashboard you'll see a new workflow entry. On this page all workflow executions are presented with their status, instance ID, workflow name, app ID, start/end time, and duration (the clock icon).

1. Click on the instance ID of the workflow you just started to drill down to the *Workflow Execution Details* page.

Here you'll see the input and output of the workflow, and the *Execution History* table with all the events. The most recent events are at the top.

2. In the *Execution History* table expand some of the events. For the `TaskScheduled` events you will see the input for the activity. For the `TaskCompleted` events you will see both input and output for the activity.

---

You've run the complete USS Enterprise diagnostics workflow end-to-end. Aspire orchestrates Valkey, the API service with its Dapr sidecar, and the Diagrid Dev Dashboard — all from a single `aspire run`. Each workflow fans out three subsystem diagnostics in parallel, prioritizes the results, and conditionally notifies the bridge when things look urgent.
