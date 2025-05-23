In this challenge, you'll explore the Dapr Workflow Management API and test the various operations that can be performed on workflow instances.

## 1. Workflow Management

The operations you'll be testing in this challenge besides starting a workflow and getting the status are:

- Suspend a workflow instance
- Resume a workflow instance
- Terminate a workflow instance
- Purge a workflow instance

> [!NOTE]
> This challenge uses the Dapr SDK to access the workflow management API. You can also use the Dapr HTTP API to make requests to the workflow management API without using an SDK. More information about the workflow management API can be found in the [Dapr docs](https://docs.dapr.io/reference/api/workflow_api/).

The workflow used in this challenge is called `NeverEndingWorkflow` and it runs indefinitely. The workflow:

- Is started with an integer input named `counter` with value `0`.
- Calls a `SendNotification` activity.
- User a timer to wait for 1 second.
- Increments the `counter` by `1`
- Continues as a new workflow instance.

![Never Ending Workflow](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/10-workflow-management/images/dapr-uni-wf-management-v1.png?raw=true)

### 1.1 Choose a language tab

Use one of the language tabs to navigate to the workflow management example. Each language tab contains a workflow application, and a Multi-App Run `dapr.yaml` file that is used to run the example.

### 1.2 Inspect the Workflow code

> [!NOTE]
> Expand the language-specific instructions to learn more about the workflow.

<details>
   <summary><b>.NET workflow code</b></summary>

Open the `NeverEndingWorkflow.cs` file located in the `WorkflowManagement` folder. This file contains the workflow code.

The input for this workflow is an integer, and gets incremented by `1` every second. The workflow will run indefinitely.

</details>

<details>
   <summary><b>Python workflow code</b></summary>

Open the `never_ending_workflow.py` file located in the `workflow_management` folder. This file contains the workflow code.

The input for this workflow is an integer, and gets incremented by `1` every second. The workflow will run indefinitely.

</details>

### 1.3 Inspect the Activity code

> [!NOTE]
> Expand the language-specific instructions to learn more about the activity.

<details>
   <summary><b>.NET activity code</b></summary>

Open the `SendNotification.cs` file located in the `WorkflowManagement/Activities` folder. This activity only logs the activity input (the counter) and returns true.

</details>

<details>
   <summary><b>Python activity code</b></summary>

Open the `never_ending_workflow.py` file located in the `workflow_management` folder. The `send_notification` activity function can be found below the workflow definition. The activity only prints the activity input value.

</details>

### 1.4. Inspect the startup code

> [!NOTE]
> Expand the language-specific instructions to learn more about workflow registration, workflow runtime startup, and HTTP endpoints to start the workflow.

<details>
   <summary><b>.NET registration and endpoints</b></summary>

Locate the `Program.cs` file in the `WorkflowManagement` folder. This file contains the code to register the workflows and activities using the `AddDaprWorkflow()` extension method.

The application has the following HTTP endpoints:

- `start/{counter}`, a POST endpoint that is used to start the workflow, and accepts an integer as the input.
- `status/{instanceId}`, a GET endpoint that is used to get the status of the workflow instance, and accepts a workflow instance ID as the input.
- `suspend/{instanceId}`, a POST endpoint that is used to suspend the workflow instance, and accepts a workflow instance ID as the input.
- `resume/{instanceId}`, a POST endpoint that is used to resume a suspended workflow instance, and accepts a workflow instance ID as the input.
- `terminate/{instanceId}`, a POST endpoint that is used to terminate the workflow instance, and accepts a workflow instance ID as the input.
- `purge/{instanceId}`, a DELETE endpoint that is used to delete the workflow instance, and accepts a workflow instance ID as the input.

All methods use the `DaprWorklowClient` to perform the workflow management operations.

</details>

<details>
   <summary><b>Python workflow runtime and endpoints</b></summary>

Locate the `app.py` file in the `workflow_management` folder. This file contains the code to start the workflow runtime and the following HTTP endpoints:

- `start/{counter}`, a POST endpoint that is used to start the workflow, and accepts an integer as the input.
- `status/{instance_id}`, a GET endpoint that is used to get the status of the workflow instance, and accepts a workflow instance ID as the input.
- `suspend/{instance_id}`, a POST endpoint that is used to suspend the workflow instance, and accepts a workflow instance ID as the input.
- `resume/{instance_id}`, a POST endpoint that is used to resume a suspended workflow instance, and accepts a workflow instance ID as the input.
- `terminate/{instance_id}`, a POST endpoint that is used to terminate the workflow instance, and accepts a workflow instance ID as the input.
- `purge/{instance_id}`, a DELETE endpoint that is used to delete the workflow instance, and accepts a workflow instance ID as the input.

All methods use the `DaprWorklowClient` to perform the workflow management operations.

</details>

## 2. Run the workflow app

> [!NOTE]
> Expand the language specific instructions to start the workflow management application.

<details>
   <summary><b>Run the .NET application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *csharp/workflow-management* folder:

```bash,run
cd csharp/workflow-management
```

Install the dependencies and build the project:

```bash,run
dotnet build WorkflowManagement
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the Python application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/workflow-management/workflow_management* folder:

```bash,run
cd python/workflow-management/workflow_management
```

Create a virtual environment and activate it:

```bash,run
python3 -m venv venv
source venv/bin/activate
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
> Expand the language-specific instructions to start the never ending workflow.

<details>
   <summary><b>Start the .NET workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST \
  --url http://localhost:5262/start/0 \
  -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\r\n')
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - neverendingworkflow == SendNotification: Received input: 0.
== APP - neverendingworkflow == SendNotification: Received input: 1.
== APP - neverendingworkflow == SendNotification: Received input: 2.
== APP - neverendingworkflow == SendNotification: Received input: 3.
...
```

</details>

<details>
   <summary><b>Start the Python workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST \
  --url http://localhost:5262/start/0 \
  -i | grep -o '"instance_id":"[^"]*"' \
   | sed 's/"instance_id":"//;s/"//g' \
   | tr -d '\r\n')
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - neverendingworkflow == send_notification: Received input: 0.
== APP - neverendingworkflow == send_notification: Received input: 1.
== APP - neverendingworkflow == send_notification: Received input: 2.
== APP - neverendingworkflow == send_notification: Received input: 3.
...
```

</details>

## 4. Get the workflow status

Use the **curl** window to perform a GET request to the `status` endpoint of the application to retrieve the workflow status.

> [!NOTE]
> Expand the language-specific instructions to get the workflow instance status.

<details>
   <summary><b>Get the .NET workflow status</b></summary>

Use the **curl** window to perform a GET request to the `status` endpoint of the application to retrieve the workflow status:

```curl,run
curl --request GET  --url http://localhost:5262/status/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "exists":true,
   "isWorkflowRunning":true,
   "isWorkflowCompleted":false,
   "createdAt":"2025-04-23T15:51:43.0005152+00:00",
   "lastUpdatedAt":"2025-04-23T15:51:43.0114001+00:00",
   "runtimeStatus":0,
   "failureDetails":null
}
```

</details>

<details>
   <summary><b>Get the Python workflow status</b></summary>

Use the **curl** window to perform a GET request to the `status` endpoint of the application to retrieve the workflow status:

```curl,run
curl --request GET  --url http://localhost:5262/status/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "_WorkflowState__obj":
   {
      "instance_id":"736eb41171b94d61a8cb87e64e443c94",
      "name":"never_ending_workflow",
      "runtime_status":0,
      "created_at":"2025-05-20T14:59:29.003416",
      "last_updated_at":"2025-05-20T14:59:29.035188",
      "serialized_input":"29",
      "serialized_output":null,
      "serialized_custom_status":null,
      "failure_details":null
   }
}
```

</details>

## 5. Suspend the workflow

Use the **curl** window to make a POST request to the `suspend` endpoint of the application to suspend the workflow instance.

> [!NOTE]
> Expand the language-specific instructions to suspend the workflow instance.

<details>
   <summary><b>Suspend the .NET workflow</b></summary>

Use the **curl** window to make a POST request to the `suspend` endpoint of the application to suspend the workflow instance:

```curl,run
curl -i --request POST \
  --url http://localhost:5262/suspend/$INSTANCEID
```

Expected output:

```json,nocopy
HTTP/1.1 202 Accepted
Content-Length: 0
Date: Wed, 23 Apr 2025 15:54:08 GMT
Server: Kestrel
```

> [!NOTE]
> The workflow instance has stopped executing. The **Dapr CLI** window should not show any new log statements.

</details>

<details>
   <summary><b>Suspend the Python workflow</b></summary>

Use the **curl** window to make a POST request to the `suspend` endpoint of the application to suspend the workflow instance:

```curl,run
curl -i --request POST \
  --url http://localhost:5262/suspend/$INSTANCEID
```

Expected output:

```json,nocopy
HTTP/1.1 202 Accepted
date: Tue, 20 May 2025 15:01:20 GMT
server: uvicorn
content-length: 4
content-type: application/json
```

> [!NOTE]
> The workflow instance has stopped executing. The **Dapr CLI** window should not show any new log statements.

</details>

## 6. Resume the workflow

Use the **curl** window to make a POST request to the `resume` endpoint of the application to resume the suspended the workflow instance.

> [!NOTE]
> Expand the language-specific instructions to resume the workflow instance.

<details>
   <summary><b>Resume the .NET workflow</b></summary>

Use the **curl** window to make a POST request to the `resume` endpoint of the application to resume the suspended the workflow instance:

```curl,run
curl -i --request POST \
  --url http://localhost:5262/resume/$INSTANCEID
```

Expected output:

```json,nocopy
HTTP/1.1 202 Accepted
Content-Length: 0
Date: Wed, 23 Apr 2025 15:59:17 GMT
Server: Kestrel
```

</details>

<details>
   <summary><b>Resume the Python workflow</b></summary>

Use the **curl** window to make a POST request to the `resume` endpoint of the application to resume the suspended the workflow instance:

```curl,run
curl -i --request POST \
  --url http://localhost:5262/resume/$INSTANCEID
```

Expected output:

```json,nocopy
HTTP/1.1 202 Accepted
date: Tue, 20 May 2025 15:01:54 GMT
server: uvicorn
content-length: 4
content-type: application/json
```

</details>

## 7. Terminate the workflow

Use the **curl** window to make a POST request to the `terminate` endpoint of the application to terminate the running workflow instance.

> [!NOTE]
> Expand the language-specific instructions to terminate the workflow instance.

<details>
   <summary><b>Terminate the .NET workflow</b></summary>

Use the **curl** window to make a POST request to the `terminate` endpoint of the application to terminate the running workflow instance:

```curl,run
curl -i --request POST \
  --url http://localhost:5262/terminate/$INSTANCEID
```

Expected output:

```json,nocopy
HTTP/1.1 202 Accepted
Content-Length: 0
Date: Wed, 23 Apr 2025 15:59:17 GMT
Server: Kestrel
```

The **Dapr CLI** window should show a log statement about the workflow being terminated:

```text,nocopy
Workflow Actor <INSTANCEID>: workflow completed with status 'ORCHESTRATION_STATUS_TERMINATED' workflowName 'NeverEndingWorkflow'
```

</details>

<details>
   <summary><b>Terminate the Python workflow</b></summary>

Use the **curl** window to make a POST request to the `terminate` endpoint of the application to terminate the running workflow instance:

```curl,run
curl -i --request POST \
  --url http://localhost:5262/terminate/$INSTANCEID
```

Expected output:

```json,nocopy
HTTP/1.1 202 Accepted
date: Tue, 20 May 2025 15:02:55 GMT
server: uvicorn
content-length: 4
content-type: application/json
```

The **Dapr CLI** window should show a log statement about the workflow being terminated:

```text,nocopy
Workflow Actor <INSTANCEID>: workflow completed with status 'ORCHESTRATION_STATUS_TERMINATED' workflowName 'never_ending_workflow'
```

</details>

## 8. Purge the workflow

Use the **curl** window to make a DELETE request to the `purge` endpoint of the application to purge workflow instance from the state store.

> [!NOTE]
> Expand the language-specific instructions to purge the workflow instance.

<details>
   <summary><b>Purge the .NET workflow</b></summary>

Use the **curl** window to make a DELETE request to the `purge` endpoint of the application to purge workflow instance from the state store:

```curl,run
curl -i --request DELETE \
  --url http://localhost:5262/purge/$INSTANCEID
```

Expected output:

```json,nocopy
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
Date: Wed, 23 Apr 2025 16:04:08 GMT
Server: Kestrel
Transfer-Encoding: chunked

true
```

</details>

<details>
   <summary><b>Purge the Python workflow</b></summary>

Use the **curl** window to make a DELETE request to the `purge` endpoint of the application to purge workflow instance from the state store:

```curl,run
curl -i --request DELETE \
  --url http://localhost:5262/purge/$INSTANCEID
```

Expected output:

```json,nocopy
HTTP/1.1 202 Accepted
date: Tue, 20 May 2025 15:04:17 GMT
server: uvicorn
content-length: 4
content-type: application/json
```

</details>

## 9. Stop the workflow application

Use the **Dapr CLI** window to stop the workflow application by pressing `Ctrl+C`.

---

You've now used the Dapr Workflow Management API to start, get the status, suspend, resume, terminate, and purge a workflow instance. Let's move on to the final challenge, where you'll learn about some of the challenges of code based workflows and how to deal with them.
