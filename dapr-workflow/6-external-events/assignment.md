In this challenge, you'll explore a workflow application that demonstrates the external system interaction pattern.

## 1. External System Interaction

The external system interaction pattern is used pause the workflow until it receives an external event.

![External System Interaction](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/6-external-events/images/dapr-uni-wf-pattern-external-event-v1.png?raw=true)

The workflow in this challenge is an order workflow:

- The workflow is started with an `Order` input argument.
- If the total price of the workflow is over 250, the workflow will wait for an external `approval-event`.
- If no event is received within 120 seconds, the workflow will call the `SendNotification` activity to notify the user about the approval timeout.
- If the approval event is received and marked as *approved*, the `ProcessOrder` activity will be called.
- Finally another `SendNotification` activity is called which notifies the user about the approval.

![External System Interaction Demo](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/6-external-events/images/dapr-uni-wf-external-event-demo-v1.png?raw=true)

### 1.1. Choose a language tab

Use one of the language tabs to navigate to the external system interaction workflow example. Each language tab contains a workflow application, and a Multi-App Run `dapr.yaml` file that is used to run the example.

### 1.2. Inspect the Workflow code

> [!NOTE]
> Expand the language-specific instructions to learn more about the external system interaction workflow.

<details>
   <summary><b>.NET workflow code</b></summary>

Open the `ExternalEventsWorkflow.cs` file located in the `ExternalEvents` folder. This file contains the workflow code.

Note how the workflow uses the `WorkflowContext` to create a timer and to continue the workflow as a fresh instance.

```csharp,nocopy
try
{
    approvalStatus = await context.WaitForExternalEventAsync<ApprovalStatus>(
        eventName: "approval-event",
        timeout: TimeSpan.FromSeconds(120));
}
catch (TaskCanceledException)
{
    // Timeout occurred
    notificationMessage = $"Approval request for order {order.Id} timed out.";
    await context.CallActivityAsync(
        nameof(SendNotification),
        notificationMessage);
    return notificationMessage;
}
```

</details>

### 1.3. Inspect the Activity code

> [!NOTE]
> Expand the language-specific instructions to inspect the activities.

<details>
   <summary><b>.NET activity code</b></summary>

The workflow uses two activities, `SendNotification` and `ProcessOrder`, these are located in the `ExternalEvents/Activities` folder. Both activities are placeholders and do not contain any real logic related to sending notifications or processing orders.

*The `RequestApproval` activity is not used in the workflow at the moment.*

</details>

### 1.4. Inspect the workflow & activity registration

> [!NOTE]
> Expand the language-specific instructions to learn more about workflow registration.

<details>
   <summary><b>.NET registration and endpoints</b></summary>

Locate the `Program.cs` file in the `ExternalEvents` folder. This file contains the code to register the workflow and activities using the `AddDaprWorkflow()` extension method.

This application also has a `start` HTTP POST endpoint that is used to start the workflow, and accepts an `Order` as the input.

Note that this time an instance ID is provided to the `ScheduleNewWorkflowAsync` method:

```csharp,nocopy
var instanceId = await workflowClient.ScheduleNewWorkflowAsync(
   name: nameof(ExternalEventsWorkflow),
   instanceId: order.Id,
   input: order);
```

</details>

## 2. Run the workflow app

> [!NOTE]
> Expand the language-specific instructions to start the workflow application.

<details>
   <summary><b>Run the .NET application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *csharp/external-system-interaction* folder:

```bash,run
cd csharp/external-system-interaction
```

Install the dependencies and build the project:

```bash,run
dotnet build ExternalEvents
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

Inspect the output of the **Dapr CLI** window. Wait until the application is running before continuing.

## 3. Start the workflow

Use the **curl** window to make a POST request to the `start` endpoint of the workflow application.

> [!NOTE]
> Expand the language-specific instructions to start the external system interaction workflow.

<details>
   <summary><b>Start the .NET workflow</b></summary>

In the **curl** window, run the following command to start the workflow:

```curl,run
curl -i --request POST \
  --url http://localhost:5258/start \
  --header 'content-type: application/json' \
  --data '{"id": "b7dd836b-e913-4446-9912-d400befebec5","description": "Rubber ducks","quantity": 100,"totalPrice": 500}'
```

Expected output:

```text,nocopy
HTTP/1.1 202 Accepted
Content-Length: 0
Date: Thu, 17 Apr 2025 15:37:51 GMT
Server: Kestrel
Location: b7dd836b-e913-4446-9912-d400befebec5
```

> [!NOTE]
> The `id` field in the request body is used as the workflow instance ID. All further requests will use this ID.

The application log in the **Dapr CLI** window should contain this log statement:

```text,nocopy
== APP - externalevents == Received order: Order { Id = b7dd836b-e913-4446-9912-d400befebec5, Description = Rubber ducks, Quantity = 100, TotalPrice = 500 }.
```

</details>

## 4. Send an external event

> [!NOTE]
> Expand the language-specific instructions to send an event to the workflow instance.

<details>
   <summary><b>Send an event to the .NET workflow</b></summary>

In the **curl** window, run the following command to send an `approval-event` to the running workflow instance:

```curl,run
curl -i --request POST \
  --url http://localhost:3558/v1.0/workflows/dapr/b7dd836b-e913-4446-9912-d400befebec5/raiseEvent/approval-event \
  --header 'content-type: application/json' \
  --data '{"OrderId": "b7dd836b-e913-4446-9912-d400befebec5","IsApproved": true}'
```

Expected output:

```text,nocopy
HTTP/1.1 202 Accepted
Content-Type: application/json
Traceparent: 00-cd40670f36a8be0b1b6951f3962387c3-95440c97280a6405-01
Date: Thu, 17 Apr 2025 15:39:14 GMT
Content-Length: 2
```

The application log in the **Dapr CLI** window should contain these log statements:

```text,nocopy
== APP - externalevents == ProcessOrder: Processed order: b7dd836b-e913-4446-9912-d400befebec5.
== APP - externalevents == SendNotification: Order b7dd836b-e913-4446-9912-d400befebec5 has been approved.
```

</details>

## 5. Get the workflow status

Use the **curl** window to perform a GET request directly the Dapr workflow management API to retrieve the workflow status.

> [!NOTE]
> Expand the language-specific instructions to get the workflow instance status.

<details>
   <summary><b>Get the .NET workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3558/v1.0/workflows/dapr/b7dd836b-e913-4446-9912-d400befebec5
```

Expected output:

```json,nocopy
{
   "instanceID":"b7dd836b-e913-4446-9912-d400befebec5",
   "workflowName":"ExternalEventsWorkflow",
   "createdAt":"2025-04-17T15:37:52.010680923Z",
   "lastUpdatedAt":"2025-04-17T15:39:14.342695324Z",
   "runtimeStatus":"COMPLETED",
   "properties":{
      "dapr.workflow.input":"{\"Id\":\"b7dd836b-e913-4446-9912-d400befebec5\",\"Description\":\"Rubber ducks\",\"Quantity\":100,\"TotalPrice\":500}",
      "dapr.workflow.output":"\"Order b7dd836b-e913-4446-9912-d400befebec5 has been approved.\""
   }
}
```

</details>

## 6. Trying different workflow paths

If you want, you can run some additional tests to explore the alternative paths in the workflow by either not sending any events and therefore waiting for the 120 sec timeout, or sending an event with a `"IsApproved": false` value.

## 7. Stop the workflow application

Use the **Dapr CLI** window to stop the workflow application by pressing `Ctrl+C`.

---

You've now seen how to use the external system interaction pattern in a workflow application. Now let's have a look how to call a child workflow from a parent workflow.
