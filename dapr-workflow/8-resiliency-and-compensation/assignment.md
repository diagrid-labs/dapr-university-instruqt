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

![Compensation action](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/8-resiliency-and-compensation/images/dapr-uni-wf-compensation-demo-v1.png?raw=true)

A more realistic scenario where compensation actions are useful is when a workflow calls an activity that creates a new record in an external system. If a subsequent activity fails after the record is created, the workflow can call another activity to remove the new record, or inform another system about the failure.

### 1.1 Choose a language tab

Use one of the language tabs to navigate to the resiliency and compensation workflow example. Each language tab contains a workflow application, and a Multi-App Run `dapr.yaml` file that is used to run the example.

### 1.2 Inspect the Workflow code

> [!NOTE]
> Expand the language-specific instructions to learn more about the workflow.

<details>
   <summary><b>.NET workflow code</b></summary>

Open the `ResiliencyAndCompensationWorkflow.cs` file located in the `ResiliencyAndCompensation` folder. This file contains the workflow code.

```csharp,nocopy
var defaultActivityRetryOptions = new WorkflowTaskOptions
{
   RetryPolicy = new WorkflowRetryPolicy(
      maxNumberOfAttempts: 3,
      firstRetryInterval: TimeSpan.FromSeconds(2)),
};
```

This `WorkflowTaskOptions` defines a retry policy that retries activities up to 3 times with an initial delay of 2 seconds.

```csharp,nocopy
var result1 = await context.CallActivityAsync<int>(
   nameof(MinusOne),
   input,
   defaultActivityRetryOptions);
```

The `defaultActivityRetryOptions` are passed as the third argument to the `CallActivityAsync` methods in this workflow.

</details>

<details>
   <summary><b>Python workflow code</b></summary>

Open the `resiliency_and_compensation_workflow.py` file located in the `resiliency_and_compensation` folder. This file contains the workflow code.

```python,nocopy
default_retry_policy = wf.RetryPolicy(max_number_of_attempts=3, first_retry_interval=timedelta(seconds=2))
```

This `RetryPolicy` defines a retry policy that retries activities up to 3 times with an initial delay of 2 seconds.

```python,nocopy
 result1 = yield ctx.call_activity(minus_one, input=wf_input, retry_policy=default_retry_policy)
```

The `default_retry_policy` is passed as the third argument to the `call_activity` methods in this workflow.

</details>

### 1.3 Inspect the Activity code

> [!NOTE]
> Expand the language-specific instructions to learn about the activities.

<details>
   <summary><b>.NET activity code</b></summary>

The three activity definitions are located in the `ResiliencyAndCompensation/Activities` folder. The `MinusOne` and `PlusOne` activities, subtract and add `1` to the numeric input respectively.The `Division` activity divides `100` by the numeric input, and will result in an exception if the input is `0`.

</details>

<details>
   <summary><b>Python activity code</b></summary>

The three activity definitions are located in the `resiliency_and_compensation_workflow.py` file below the workflow definition. The `minus_one` and `plus_one` activities, subtract and add `1` to the numeric input respectively.The `division` activity divides `100` by the numeric input, and will result in an exception if the input is `0`.

</details>

### 1.4. Inspect the startup code

> [!NOTE]
> Expand the language-specific instructions to learn more about workflow registration, workflow runtime startup, and HTTP endpoints to start the workflow.

<details>
   <summary><b>.NET registration and endpoints</b></summary>

Locate the `Program.cs` file in the `ResiliencyAndCompensation` folder. This file contains the code to register the workflows and activities using the `AddDaprWorkflow()` extension method.

This application also has a `start` HTTP POST endpoint that is used to start the workflow, and accepts an integer as the input.

</details>

<details>
   <summary><b>Python workflow runtime and endpoints</b></summary>

Locate the `app.py` file in the `resiliency_and_compensation` folder.This file contains the code to start the workflow runtime and a `start` HTTP endpoint to start the workflow which accepts an integer as the input.

</details>

## 2. Run the workflow app

> [!NOTE]
> Expand the language specific instructions to start the resiliency and compensation workflow.

<details>
   <summary><b>Run the .NET workflow application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *csharp/resiliency-and-compensation* folder:

```bash,run
cd csharp/resiliency-and-compensation
```

Install the dependencies and build the project:

```bash,run
dotnet build ResiliencyAndCompensation
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the Python workflow application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/resiliency-and-compensation/resiliency_and_compensation* folder:

```bash,run
cd python/resiliency-and-compensation/resiliency_and_compensation
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
> Expand the language-specific instructions to start the resiliency and compensation workflow.

<details>
   <summary><b>Start the .NET workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST \
  --url http://localhost:5264/start/1 \
  -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\r\n')
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - resiliency == MinusOne: Received input: 1.
== APP - resiliency == Division: Received divisor: 0.
== APP - resiliency == Division: Received divisor: 0.
== APP - resiliency == Division: Received divisor: 0.
== APP - resiliency == PlusOne: Received input: 0.
```

> [!NOTE]
> The `Division` activity is retried 3 times due to the retry policy. The exception is caught in the workflow, and the `PlusOne` activity is called to compensate for `MinusOne` activity.

</details>

<details>
   <summary><b>Start the Python workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST \
  --url http://localhost:5264/start/1 \
  -i | grep -o '"instance_id":"[^"]*"' \
   | sed 's/"instance_id":"//;s/"//g' \
   | tr -d '\r\n')
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - resiliency == minus_one: Received input: 1.
== APP - resiliency == division: Received divisor: 0.
== APP - resiliency == plus_one: Received input: 0.
```

> [!NOTE]
> The exception is caught in the workflow, and the `PlusOne` activity is called to compensate for `MinusOne` activity.

</details>

## 4. Get the workflow status

Use the **curl** window to perform a GET request directly the Dapr workflow management API to retrieve the workflow status.

> [!NOTE]
> Expand the language-specific instructions to get the workflow instance status.

<details>
   <summary><b>Get the .NET workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3564/v1.0/workflows/dapr/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "instanceID":"<INSTANCE_ID>",
   "workflowName":"ResiliencyAndCompensationWorkflow",
   "createdAt":"2025-04-23T09:37:58.941845115Z",
   "lastUpdatedAt":"2025-04-23T09:38:03.049028901Z",
   "runtimeStatus":"COMPLETED",
   "properties":{
      "dapr.workflow.custom_status":"\"Compensated MinusOne activity with PlusOne activity.\"",
      "dapr.workflow.input":"1","dapr.workflow.output":"1"
   }
}
```

> [!NOTE]
> The `custom_status` field contains the message that is set in the workflow after the compensation action is called.

</details>

<details>
   <summary><b>Get the Python workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3564/v1.0/workflows/dapr/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "instanceID":"<INSTANCE_ID>",
   "workflowName":"resiliency_and_compensation_workflow",
   "createdAt":"2025-04-23T09:37:58.941845115Z",
   "lastUpdatedAt":"2025-04-23T09:38:03.049028901Z",
   "runtimeStatus":"COMPLETED",
   "properties":{
      "dapr.workflow.custom_status":"\"Compensated minus_one activity with plus_one activity.\"",
      "dapr.workflow.input":"1","dapr.workflow.output":"1"
   }
}
```

> [!NOTE]
> The `custom_status` field contains the message that is set in the workflow after the compensation action is called.

</details>

## 5. Trying a different retry policy

If you want, you can run some additional tests to explore different retry policies. Update the `(Workflow)RetryPolicy` in the workflow. Use the language specific reference to see what options are available.

- [.NET `WorkflowRetryPolicy` definition on GitHub](
https://github.com/dapr/dotnet-sdk/blob/master/src/Dapr.Workflow/WorkflowRetryPolicy.cs)
- [Python `RetryPolicy` definition on GitHub](
https://github.com/dapr/python-sdk/blob/main/ext/dapr-ext-workflow/dapr/ext/workflow/retry_policy.py) (Currently there is an issue with the `RetryPolicy` in the Python SDK, so you may not be able to test this.)

## 6. Stop the workflow application

Use the **Dapr CLI** window to stop the workflow application by pressing `Ctrl+C`.

---

You now know how to use retry policies in workflows, and how to use compensation actions. Now, let's have a look at a more realistic application that combines various workflow patterns.
