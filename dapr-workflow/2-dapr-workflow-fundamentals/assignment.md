In this challenge, you'll learn:

- How Dapr workflows and activities are defined in code.
- How workflows are started.
- How to get the status of a workflow instance.
- How the workflow engine persists workflow state.

> [!NOTE]
> All the code you see in this Dapr University track is available in the [Dapr QuickStarts](https://github.com/dapr/quickstarts/) repository in the `tutorials/workflow` folder. If you want to explore more code samples for other Dapr APIs in this repo, you can do so after completing this track.

## 1. Workflows and Activities

Workflows are authored in code using the Dapr Workflow SDK. Workflows are composed of activities, which are the building blocks of a workflow. Activities typically contain code that performs one specific task, such as synchronously calling another service, storing data in a state store, performing a calculation, or publishing a message to a topic.

![Workflow with activities](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/2-dapr-workflow-fundamentals/images/dapr-uni-wf-fundamental-v1.png?raw=true)

Workflows orchestrate the activities in a specific order. Workflow code typically contains calls to activities, business logic (if/else statements) and other control logic (try/catch block) based on the outputs of activities to determine which activity should be executed next. Workflow code should be deterministic, meaning that the same input for either workflows or activities, should always result in the same output. Any non-deterministic code should be placed in an activity. More information about (non)deterministic code is covered in the last challenge of this Dapr University track.

## 2. A basic workflow demo

The workflow in this challenge consists of two activities that are called in sequence.

- The workflow is started with an input of `"One"`.
- The first activity adds `" Two"` to the input and returns `"One Two"`.
- The second activity adds `" Three"` to the output of the first activity.
- The final output of the workflow is `"One Two Three"`.

![Basic Workflow](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/2-dapr-workflow-fundamentals/images/dapr-uni-wf-fundamental-basic-v1.png?raw=true)

### 2.1 Choose a language tab

Use one of the language tabs to navigate to the basic workflow example. Each language tab contains a workflow application and a Dapr Multi-App Run `dapr.yaml` file that is used to start the application with a Dapr sidecar.

### 2.2 Inspect the Workflow code

> [!NOTE]
> Expand the language-specific instructions to learn more about workflow code.

<details>
   <summary><b>.NET workflow</b></summary>

Open the `BasicWorkflow.cs` file located in the `Basic` folder. This file contains the workflow code.

The `BasicWorkflow` class inherits from an abstract `Workflow` class provided by the Dapr Workflow SDK. The generic arguments specify the input and output types of the workflow.

The `BasicWorkflow` class overrides the `RunAsync` method from the base class. This method is the entry point of the workflow.

Workflows are asynchronous and return a `Task` object. In this case, the return type is `Task<string>`.

The `WorkflowContext` input argument is provided by the Dapr Workflow SDK and contains properties and methods of the workflow instance. The second input argument is the input argument for the workflow.

You can use any type of input and output for the workflow, as long as they are serializable.

The body of the `RunAsync` method in this example contains two calls to activities using the `CallActivityAsync` method. The generic argument defines the output type of the activity. The first input argument is the name of the activity; the second input argument is the input for the activity.

</details>

<details>
   <summary><b>Python workflow</b></summary>

Open the `basic_workflow.py` file located in the `basic` folder. This file contains the workflow code.

The Dapr workflow SDK is imported and aliased as `wf`.

```python,nocopy
import dapr.ext.workflow as wf
```

A new `WorkflowRuntime` instance is created: `wf_runtime = wf.WorkflowRuntime()`. This instance is used to decorate the `basic_workflow` function as a Dapr workflow.

The `wf.DaprWorkflowContext` input argument is provided by the Dapr Workflow SDK. This object contains properties and methods of the workflow instance. The second input argument is the input argument for the workflow.

You can use any type of input and output for the workflow, as long as they are serializable.

The body of the `basic_workflow` function in this example contains two calls to activities using the `call_activity` method. The first input argument is the name of the activity function; the second input argument is the input for the activity.

</details>

### 2.3 Inspect the Activity code

> [!NOTE]
> Expand the language-specific instructions to learn more about activity code.

<details>
   <summary><b>.NET activities</b></summary>

Open the `Activity1.cs` file located in the `Basic/Activities` folder. This file contains the code for Activity1.

The `Activity1` class inherits from an abstract `WorkflowActivity` class provided by the Dapr Workflow SDK, the generic arguments specify the input and the output types of the activity.

The `Activity1` class overrides the `RunAsync` method from the base class. This method is the entry point of the activity.

Activities are asynchronous and return a `Task` object. In this case, the return type is `Task<string>`.

The `WorkflowActivityContext` input argument is provided by the Dapr Workflow package and contains the instance ID of workflow. The second input argument is the input argument for the workflow.

You can use any type of input and output for the activity, as long as they are serializable.

The body of the `RunAsync` method in this example just does a `Console.WriteLine` to echo the input and returns a string concatenation of the input and "Two".

</details>

<details>
   <summary><b>Python activities</b></summary>

Open the `basic_workflow.py` file located in the `basic` folder. This file contains the workflow and activity code.

Activities are defined as functions and decorated with the `@wf_runtime.activity(...)` decorator and contains the name of the activity.

The `WorkflowActivityContext` input argument is provided by the Dapr Workflow SDK. This type contains the instance ID of workflow. The second input argument is the input argument for the workflow.

You can use any type of input and output for the activity, as long as they are serializable.

The body of the activity function in this example just does a `print` to echo the input and returns a string concatenation of the input and "Two".

</details>

###

> [!IMPORTANT]
> Typically, activities contain code that performs one specific task, such as calling an external service, storing data in a state store, performing a calculation, or publishing a message. A more realistic example is shown in the *Combined Patterns* challenge later in this learning track.

### 2.4 Inspect the workflow & activity registration

> [!NOTE]
> Expand the language-specific instructions to learn more about workflow registration.

<details>
   <summary><b>.NET registration and endpoints</b></summary>

Workflows and activities need to be registered in the workflow application. This is to ensure that Dapr can find the workflow and activities when they are scheduled.

Locate the `Program.cs` file in the `Basic` folder. This file contains the code to register the workflow and activities using the `AddDaprWorkflow()` extension method.

This application also has a `start` HTTP POST endpoint that is used to start the workflow. It accepts a `string` as input, and this input is passed on to the workflow.

The `start` method also contains the `DaprWorkflowClient` as an input argument. This is injected by the Dapr SDK. The `DaprWorkflowClient` is used to schedule a new workflow using the `ScheduleNewWorkflowAsync` method. The first input argument for this method is the name of the workflow; the second input argument is the input for the workflow. The `ScheduleNewWorkflowAsync` method return the instance ID of the workflow that is scheduled. The ID is used for other workflow operations that can be done with the `DaprWorkflowClient`. This will be covered in the *Workflow Management* challenge later in this learning track.

</details>

<details>
   <summary><b>Python workflow runtime & endpoints</b></summary>

> [!NOTE]
> All Python demos in this learning track use the FastAPI framework.

Locate the `app.py` file in the `basic` folder. This file contains the code to start the workflow runtime and an HTTP endpoint to start the workflow.

The FastAPI lifespan is used to start the workflow runtime when the application starts and shutdown the workflow runtime when the application stops:

```python,nocopy
@asynccontextmanager
async def lifespan(app: FastAPI):
    wf_runtime.start()
    yield
    wf_runtime.shutdown()
```

The `app.py` file also contains the `start` HTTP POST endpoint that is used to start the workflow. It accepts a `str` as input, and this input is passed on to the workflow.

The `start` method uses the `DaprWorkflowClient` from the Dapr SDK. The `DaprWorkflowClient` is used to schedule a new workflow using the `schedule_new_workflow` method. The first input argument for this method is the name of the workflow; the second input argument is the input for the workflow. The `schedule_new_workflow` method return the instance ID of the workflow that is scheduled. The ID is used for other workflow operations that can be done with the `DaprWorkflowClient`. This will be covered in the *Workflow Management* challenge later in this learning track.

</details>

## 3. Run the workflow application

> [!NOTE]
> Expand the language-specific instructions to start the workflow application.

<details>
   <summary><b>Run the .NET application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *csharp/fundamentals* folder:

```bash,run
cd csharp/fundamentals
```

Install the dependencies and build the project:

```bash,run
dotnet build Basic
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the Python application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *csharp/fundamentals* folder:

```bash,run
cd python/fundamentals/basic
```

Install the dependencies:

```bash,run
pip3 install -r requirements.txt
```

Run the application using the Dapr CLI:

```bash,run
cd ..
dapr run -f .
```

</details>

###

Inspect the output of the **Dapr CLI** window. Wait until the application is running before continuing.

## 4. Start the Basic workflow

Use the **curl** window to make a POST request to the `start` endpoint of the workflow application and provide `One` as the input.

> [!NOTE]
> Expand the language-specific instructions to start the basic workflow.

<details>
   <summary><b>Start the .NET workflow</b></summary>

In the **curl** window, run the following command to start the workflow:

```curl,run
curl -i --request POST http://localhost:5254/start/One
```

>[!WARNING]
> You might see a warning in the Dapr CLI log window about `Error processing operation DaprBuiltInActorNotFoundRetries.`. Don't worry, this is a transient error, the Dapr process is trying to communicate to the actor that is responsible for scheduling the workflow. You'll see this frequently since the sandbox environment is quite slow.

Expected output:

```text,nocopy
HTTP/1.1 202 Accepted
Content-Length: 0
Date: Wed, 16 Apr 2025 13:54:29 GMT
Server: Kestrel
Location: 05f63e15a3724c5d86386922919378d6
```

>[!IMPORTANT]
> Starting a workflow is an asynchronous operation. The workflow engine will return a `202 Accepted` response immediately, even if the workflow has not yet started executing. The workflow engine will schedule the workflow in the background and the workflow application will run the workflow and the activities. Since the workflow could be running for a long time or even indefinitely, the workflow engine will not wait for the workflow to complete before returning a response.

> [!NOTE]
> The `Location` header in the response contains the workflow instance ID. You can use this ID to get the status of the workflow instance you just started.

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - basic == Activity1: Received input: One.
== APP - basic == Activity2: Received input: One Two.
```

> [!IMPORTANT]
> Now run the following curl command to start the workflow again. This time, the instance ID will be captured in an environment variable, `$INSTANCEID`, and this variable is used in subsequent calls to retrieve the workflow status in the next section without the need to manually copy/paste the instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST --url http://localhost:5254/start/One \
  -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\r\n')
```

You can verify the value of the `$INSTANCEID` variable by running the following command in the **curl** window:

```bash,run
echo $INSTANCEID
```

</details>

<details>
   <summary><b>Start the Python workflow</b></summary>

In the **curl** window, run the following command to start the workflow:

```curl,run
curl -i --request POST http://localhost:5254/start/One
```

>[!WARNING]
> You might see a warning in the Dapr CLI log window about `Error processing operation DaprBuiltInActorNotFoundRetries.`. Don't worry, this is a transient error, the Dapr process is trying to communicate to the actor that is responsible for scheduling the workflow. You'll see this frequently since the sandbox environment is quite slow.

Expected output:

```text,nocopy
HTTP/1.1 202 Accepted
date: Mon, 19 May 2025 12:40:15 GMT
server: uvicorn
content-length: 50
content-type: application/json

{"instance_id":"<INSTANCE_ID>"}
```

>[!IMPORTANT]
> Starting a workflow is an asynchronous operation. The workflow engine will return a `202 Accepted` response immediately, even if the workflow has not yet started executing. The workflow engine will schedule the workflow in the background and the workflow application will run the workflow and the activities. Since the workflow could be running for a long time or even indefinitely, the workflow engine will not wait for the workflow to complete before returning a response.

> [!NOTE]
> The `instance_id` field in the response contains the workflow instance ID. You can use this ID to get the status of the workflow instance you just started.

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - basic == activity1: Received input: One.
== APP - basic == activity2: Received input: One Two.
```

> [!IMPORTANT]
> Now run the following curl command to start the workflow again. This time, the instance ID will be captured in an environment variable, `$INSTANCEID`, and this variable is used in subsequent calls to retrieve the workflow status in the next section without the need to manually copy/paste the instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST --url http://localhost:5254/start/One \
  -i | grep -o '"instance_id":"[^"]*"' \
   | sed 's/"instance_id":"//;s/"//g' \
   | tr -d '\r\n')
```

You can verify the value of the `$INSTANCEID` variable by running the following command in the **curl** window:

```bash,run
echo $INSTANCEID
```

</details>

## 5. Get the workflow status

Inspect the Dapr output in the **Dapr CLI** window. It should contain a message that the workflow has been completed successfully.

```text,nocopy
Workflow Actor '<INSTANCEID>': workflow completed with status 'ORCHESTRATION_STATUS_COMPLETED' workflowName 'BasicWorkflow'
```

> [!NOTE]
> Dapr workflow uses Dapr actors internally to manage the workflow and activity state. That is why you'll see actors mentioned in the Dapr log output.

We don't want to rely on the Dapr log output to get the status of a workflow instance. Instead, we can use the Dapr Workflow Management API to get the status of a workflow instance.

Use the **curl** window to perform a GET request directly the Dapr workflow management API to retrieve the workflow status.

> [!NOTE]
> Expand the language-specific instructions to get the workflow instance status.

<details>
   <summary><b>Get the .NET workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3554/v1.0/workflows/dapr/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable that contains the workflow instance ID that is captured from the `instance_id` field in the previous step.

Expected output:

```json,nocopy
{
   "instanceID":"05f63e15a3724c5d86386922919378d6",
   "workflowName":"basic_workflow",
   "createdAt":"2025-04-16T13:54:30.688455621Z",
   "lastUpdatedAt":"2025-04-16T13:54:30.720682100Z",
   "runtimeStatus":"COMPLETED",
   "properties": {
      "dapr.workflow.input":"\"One\"",
      "dapr.workflow.output":"\"One Two Three\""
   }
}
```

The workflow status contains the workflow instance ID, the workflow name, the created and last updated timestamps, the runtime status (`COMPLETED`), and the input and output of the workflow.

</details>

## 6. Stop the workflow application

Use the **Dapr CLI** window to stop the workflow application by pressing `Ctrl+C`.

## 7. Workflow state and replay

Dapr workflow uses durable execution, which means the workflow state is persisted to a state store. Each workflow state change is persisted to the state store. This includes:

- The start of a workflow, including the workflow input.
- The start and completion of an activity, including the input and output of the activity.
- The completion of a workflow, including the workflow output.

This animation shows when workflow state is persisted and retrieved during workflow replays:

<video src="https://play.instruqt.com/assets/tracks/gauq2r9sowaz/900f79071ad87ee1192c3e68989db1e6/assets/dapr-workflow-replay.mp4" controls></video>

The state store component used by Dapr workflow in this example is defined in the `state_redis.yaml` file. This file is not visible in the file explorer since it's located in a different folder.

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  version: v1
  initTimeout: 1m
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
  - name: actorStateStore
    value: "true"
```

> [!IMPORTANT]
> The `actorStateStore` metadata property is set to `true` to enable the use of this state store for Dapr actors. This is required for the workflow engine to work correctly.

Use the **Redis** window and use the following command to list all the keys in the Redis container that belong to the `basic` workflow you've just executed:

```bash,run
keys *basic||dapr.internal.default.basic.workflow*
```

The expected output should be similar to this:

```text,nocopy
 1) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||history-000007"
 2) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||customStatus"
 3) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||history-000003"
 4) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||history-000008"
 5) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||history-000006"
 6) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||history-000001"
 7) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||metadata"
 8) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||history-000005"
 9) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||history-000002"
10) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||history-000000"
11) "basic||dapr.internal.default.basic.workflow||05f63e15a3724c5d86386922919378d6||history-000004"
```

> [!WARNING]
> You should never edit the workflow state directly, to prevent corrupting the data of workflows that are still running. The Dapr Workflow Client is used to manage workflow instance data, and this is covered in the *Workflow Management* challenge later in this learning track.

---

You now know how Dapr workflows and activities are defined in code, how to start a workflow and get its status, and how the workflow engine persists workflow state. Let's continue with the various workflow patterns you can apply in your workflow applications. The first one is *task chaining*.
