In this challenge, you'll explore a workflow application that demonstrates the monitor pattern.

## 1. Monitor

The monitor pattern is used to execute recurring tasks, for instance running a nightly job to clean up cloud resources. Workflows that use the monitor pattern can run indefinitely or it can stop based on a condition, such as the output of an activity.

![Monitor](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/5-monitor/images/dapr-uni-wf-pattern-monitor-v1.png?raw=true)

The workflow in this challenge consists of one activity and calling two methods on the `WorkflowContext`.

- The workflow is started with an input argument `counter` with value `0`.
- The `CheckStatus` activity is called which simulates a status of an external resource.
- If the status is not ready, the workflow creates a timer via the `WorkflowContext`, and waits until the timer expires.
- The workflow increments the `counter` and continues as a fresh workflow instance (keeping the same instance ID) via the `ContinueAsNew` method on the `WorkflowContext`. This means that the workflow instance does not have its historical data associated to it anymore.

![Monitor Demo](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/5-monitor/images/dapr-uni-wf-monitor-demo-v1.png?raw=true)

> [!IMPORTANT]
> This continuation of the workflow is essentially a way of running the workflow in a loop, but in a deterministic way. Use this method instead of doing a `while` loop in the workflow code.

### 1.1. Choose a language tab

Use one of the language tabs to navigate to the monitor workflow example. Each language tab contains a workflow application, and a Multi-App Run `dapr.yaml` file that is used to run the example.

### 1.2. Inspect the Workflow code

> [!NOTE]
> Expand the language-specific instructions to learn more about the monitor workflow.

<details>
   <summary><b>.NET workflow code</b></summary>

Open the `MonitorWorkflow.cs` file located in the `Monitor` folder. This file contains the workflow code.

Note how the workflow uses the `WorkflowContext` to create a timer and to continue the workflow as a fresh instance.

```csharp,nocopy
if (!status.IsReady)
{
   await context.CreateTimer(TimeSpan.FromSeconds(1));
   counter++;
   context.ContinueAsNew(counter);
}
```

</details>

<details>
   <summary><b>Python workflow code</b></summary>

Open the `monitor_workflow.py` file located in the `monitor-pattern/monitor` folder. This file contains the workflow code.

Note how the workflow uses the `WorkflowContext` to create a timer and to continue the workflow as a fresh instance.

```python,nocopy
if not status.is_ready:
   yield ctx.create_timer(fire_at=timedelta(seconds=2))
   yield ctx.continue_as_new(counter + 1)
```

</details>

### 1.3. Inspect the Activity code

> [!NOTE]
> Expand the language-specific instructions to inspect the activity.

<details>
   <summary><b>.NET activity code</b></summary>

The workflow uses only one activity, `CheckStatus`, and is located in the `Monitor/Activities` folder. It uses a random number generator to simulate the status of a fictional external resource.

</details>

<details>
   <summary><b>Python activity code</b></summary>

The workflow uses only one activity, `check_status`, and is located in the `monitor_workflow.py` file below the workflow definition. It uses a random number generator to simulate the status of a fictional external resource.

</details>

### 1.4. Inspect the startup code

> [!NOTE]
> Expand the language-specific instructions to learn more about workflow registration, workflow runtime startup, and HTTP endpoints to start the workflow.

<details>
   <summary><b>.NET registration and endpoints</b></summary>

Locate the `Program.cs` file in the `Monitor` folder. This file contains the code to register the workflow and activities using the `AddDaprWorkflow()` extension method.

This application also has a `start` HTTP POST endpoint that is used to start the workflow, and accepts an array of strings as the input.

</details>

<details>
   <summary><b>Python workflow runtime and endpoints</b></summary>

Locate the `app.py` file in the `monitor` folder. This file contains the code to start the workflow runtime and a `start` HTTP endpoint to start the workflow.

</details>

## 2. Run the workflow app

> [!NOTE]
> Expand the language-specific instructions to start the workflow application.

<details>
   <summary><b>Run the .NET application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *csharp/monitor-pattern* folder:

```bash,run
cd csharp/monitor-pattern
```

Install the dependencies and build the project:

```bash,run
dotnet build Monitor
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the Python application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/monitor-pattern/monitor* folder:

```bash,run
cd python/monitor-pattern/monitor
```

Install the dependencies:

```bash,run
pip3 install -r requirements.txt
```

Move one folder up and run the application using the Dapr CLI:

```bash,run
cd ..
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Inspect the output of the **Dapr CLI** window. Wait until the application is running before continuing.

## 3. Start the workflow

Use the **curl** window to make a POST request to the `start` endpoint of the workflow application.

> [!NOTE]
> Expand the language-specific instructions to start the monitor workflow.

<details>
   <summary><b>Start the .NET workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST \
  --url http://localhost:5257/start/0 \
  -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\r\n')
```

In the **Dapr CLI** window you should see application logs with the incremented counter value:

```text,nocopy
== APP - monitor == CheckStatus: Received input: 0.
== APP - monitor == CheckStatus: Received input: 1.
== APP - monitor == CheckStatus: Received input: 2.
...
```

>[!NOTE]
> The exact number of log statements can vary based on the random number generator in the `CheckStatus` activity.

</details>

<details>
   <summary><b>Start the Python workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST \
  --url http://localhost:5257/start/0 \
  -i | grep -o '"instance_id":"[^"]*"' \
   | sed 's/"instance_id":"//;s/"//g' \
   | tr -d '\r\n')
```

In the **Dapr CLI** window you should see application logs with the incremented counter value:

```text,nocopy
== APP - monitor == check_status: Received input: 0.
== APP - monitor == check_status: Received input: 1.
== APP - monitor == check_status: Received input: 2.
...
```

>[!NOTE]
> The exact number of log statements can vary based on the random number generator in the `check_status` activity.

</details>

## 4. Get the workflow status

Use the **curl** window to perform a GET request directly the Dapr workflow management API to retrieve the workflow status.

> [!NOTE]
> Expand the language-specific instructions to get the workflow instance status.

<details>
   <summary><b>Get the .NET workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3557/v1.0/workflows/dapr/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "instanceID":"<INSTANCE_ID>",
   "workflowName":"MonitorWorkflow",
   "createdAt":"2025-04-17T14:45:18.000956270Z",
   "lastUpdatedAt":"2025-04-17T14:45:18.012774986Z",
   "runtimeStatus":"COMPLETED",
   "properties":{
      "dapr.workflow.input":"7",
      "dapr.workflow.output":"\"Status is healthy after checking 7 times.\""
   }
}
```

> The actual number of the counter can vary based on the random number generator in the `CheckStatus` activity.

</details>

<details>
   <summary><b>Get the Python workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3557/v1.0/workflows/dapr/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "instanceID":"<INSTANCE_ID>",
   "workflowName":"monitor_workflow",
   "createdAt":"2025-04-17T14:45:18.000956270Z",
   "lastUpdatedAt":"2025-04-17T14:45:18.012774986Z",
   "runtimeStatus":"COMPLETED",
   "properties":{
      "dapr.workflow.input":"7",
      "dapr.workflow.output":"\"Status is healthy after checking 7 times.\""
   }
}
```

> The actual number of the counter can vary based on the random number generator in the `check_status` activity.

</details>

## 5. Stop the workflow application

Use the **Dapr CLI** window to stop the workflow application by pressing `Ctrl+C`.

---

You've now seen how to use the monitor pattern in a workflow application. Let's move on another pattern: *external system interaction*.
