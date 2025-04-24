# Resiliency and Compensation

In this challenge, you'll learn:

- How to add retry policies when calling activities.
- How to use try/catch blocks in workflows and how to compensate for failing activity calls.

## 1. Resiliency and Compensation

**Resiliency**

Activities can fail for various reasons, perhaps the service that is called in the activity returns an unexpected result, or the service is temporarily unavailable. For transient failures, you can write retry policies in the workflow to retry activity calls.

These workflow retry policies are different from the Dapr yaml based declarative policies for components or apps. If code inside activities use the Dapr API to interact with components or apps it is recommended to use the yaml based resiliency policies. If the activity does not use any Dapr API, use the retry policies in the workflow code.

**Compensation actions**

When authoring workflows, you should anticipate handling exceptions and potentially compensate for any failed activity calls. This is especially important when mutations are made to external systems, before the failure occurred, but these mutations need to be rolled back after an activity failure.

The workflow in this challenge performs a simplistic calculation where the first activity, `MinusOne`, subtracts 1 from the numeric workflow input, the result is used as the divisor in the second activity, `Division`. The result of the division is passed as the output of the workflow. If the workflow input is `1`, the divisor results in `0`, causing an exception in the `Division` activity, which would result in a failed workflow. The workflow in this challenge contains a try/catch block that catches the exception, and makes a call to another activity, `PlusOne`, to perform a compensation action, to reset the input value.

![Compensation action](images/dapr-uni-wf-compensation-demo-v1.png)

A more realistic scenario where compensation actions are useful is when a workflow calls an activity that creates a new record in an external system. If a subsequent activity fails after the record is created, the workflow can call another activity to remove the new record, or inform another system about the failure.

### 1.1 Choose a language tab

Use one of the language tabs to navigate to the resiliency and compensation workflow example. Each language tab contains a workflow application, and a Multi-App Run `dapr.yaml` file that is used to run the example.

### 1.2 Inspect the Workflow code

<details>
   <summary><b>.NET</b></summary>

Open the `ResiliencyAndCompensationWorkflow.cs` file located in the `ResiliencyAndCompensation` folder. This file contains the workflow code.

```csharp
var defaultActivityRetryOptions = new WorkflowTaskOptions
{
   RetryPolicy = new WorkflowRetryPolicy(
      maxNumberOfAttempts: 3,
      firstRetryInterval: TimeSpan.FromSeconds(2)),
};
```

This `WorkflowTaskOptions` defines a retry policy that retries activities up to 3 times with an initial delay of 2 seconds.

```csharp
var result1 = await context.CallActivityAsync<int>(
   nameof(MinusOne),
   input,
   defaultActivityRetryOptions);
```

The `defaultActivityRetryOptions` are passed as the third argument to the `CallActivityAsync` methods in this workflow.

</details>

### 1.3 Inspect the Activity code

<details>
   <summary><b>.NET</b></summary>

The three activity definitions are located in the `ResiliencyAndCompensation/Activities` folder. The `MinusOne` and `PlusOne` activities, subtract and `1` to the numeric input.The `Division` activity divides `100` by the numeric input, and will result in an exception if the input is `0`.

</details>

### 1.4. Inspect the workflow & activity registration

Use the language-specific instructions to learn more about workflow registration.

<details>
   <summary><b>.NET</b></summary>

Locate the `Program.cs` file in the `ResiliencyAndCompensation` folder. This file contains the code to register the workflows and activities using the `AddDaprWorkflow()` extension method.

This application also has a `start` HTTP POST endpoint that is used to start the workflow, and accepts an integer as the input.

</details>

## 2. Start the workflow app

Use the language specific instructions to start the basic workflow.

<details>
   <summary><b>Run the .NET workflow</b></summary>

Install the dependencies and build the project:

```bash
dotnet build TaskChaining
```

Run the application using the Dapr CLI:

```bash
dapr run -f .
```
</details>

Inspect the output of the **Dapr CLI** window. The application should now be running.

## 3. Start the workflow

Use the **curl** window to make a POST request to the `start` endpoint of the workflow application.

Use the language-specific instructions to start the external system interaction workflow.

<details>
   <summary><b>Start the .NET workflow</b></summary>

In the **curl** window, run the following command to start the workflow:

```curl
curl -i --request POST \
  --url http://localhost:5264/start/1
```

Expected output:

```text
HTTP/1.1 202 Accepted
Content-Length: 0
Date: Wed, 23 Apr 2025 09:37:58 GMT
Server: Kestrel
Location: da2351d19c874a79a3f66c709a98be61
```

The **Dapr CLI** window should contain these application log statements:

```text
== APP - resiliency == MinusOne: Received input: 1.
== APP - resiliency == Division: Received divisor: 0.
== APP - resiliency == Division: Received divisor: 0.
== APP - resiliency == Division: Received divisor: 0.
== APP - resiliency == PlusOne: Received input: 0.
```

> [!NOTE]
> The `Division` activity is retried 3 times due to the retry policy. The exception is caught in the workflow, and the `PlusOne` activity is called to compensate for `MinusOne` activity.

</details>

## 4. Get the workflow status

Use the **curl** window to perform a GET request directly the Dapr workflow management API to retrieve the workflow status.

Use the language-specific instructions to get the workflow instance status.

<details>
   <summary><b>Get the .NET workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl
curl --request GET --url http://localhost:3564/v1.0/workflows/dapr/<INSTANCEID>
```

Where `<INSTANCEID>` is the workflow instance ID you received in the `Location` header in the previous step.

Expected output:

```json
{"instanceID":"da2351d19c874a79a3f66c709a98be61","workflowName":"ResiliencyAndCompensationWorkflow","createdAt":"2025-04-23T09:37:58.941845115Z","lastUpdatedAt":"2025-04-23T09:38:03.049028901Z","runtimeStatus":"COMPLETED","properties":{"dapr.workflow.custom_status":"\"Compensated MinusOne activity with PlusOne activity.\"","dapr.workflow.input":"1","dapr.workflow.output":"1"}}
```

> [!NOTE]
> The `custom_status` field contains the message that is set in the workflow after the compensation action is called.

</details>

## 5. Trying a different retry policy

If you want, you can run some additional tests to explore different retry policies. Update the `WorkflowRetryPolicy` in the workflow. Use the language specific reference to see what options are available.

- [.NET WorkflowRetryPolicy definition on GitHub](
https://github.com/dapr/dotnet-sdk/blob/master/src/Dapr.Workflow/WorkflowRetryPolicy.cs)

## 6. Stop the workflow application

Use the **Dapr CLI** window to stop the workflow application by pressing `Ctrl+C`.

---

You now know how to use retry policies in workflows, and how to use compensation actions. Now, let's have a look at a more realistic application that combines various workflow patterns.
