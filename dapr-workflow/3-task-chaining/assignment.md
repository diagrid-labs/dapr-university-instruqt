In this challenge, you'll explore a workflow application that demonstrates the task chaining pattern.

## 1. Task Chaining

The task chaining pattern is used when the order of execution of the activities in the workflow is important. Typically this means there is a dependency between the activities. For example: the output of one activity is used as input for the next activity.

![Task Chaining](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/3-task-chaining/images/dapr-uni-wf-pattern-task-chaining-v1.png?raw=true)

The workflow in this challenge consists of three activities that are called in sequence.

- The workflow is started with an input of `"This"`.
- The first activity adds `" is"` to the input and returns `"This is"`.
- The second activity adds `" task"` to the output of the first activity and returns `"This is task"`.
- The third activity adds `" chaining"` to the output of the second activity and returns `"This is task chaining"`
- The output of the workflow is `"This is task chaining"`.

![Task Chaining Demo](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/3-task-chaining/images/dapr-uni-wf-task-chaining-demo-v1.png?raw=true)

### 1.1. Choose a language tab

Use one of the language tabs to navigate to the task chaining workflow example. Each language tab contains a workflow application, and a Multi-App Run `dapr.yaml` file that is used to run the example.

### 1.2. Inspect the Workflow code

> [!NOTE]
> Expand the language-specific instructions to learn more about the task chaining workflow.

<details>
   <summary><b>.NET workflow code</b></summary>

Open the `ChainingWorkflow.cs` file located in the `TaskChaining` folder. This file contains the workflow code.

The workflow has an `input` of type `string`. This input is used as the input for the first activity. Each activity output is used as the input for the next activity. The output of the last activity is returned as the workflow output.

</details>

<details>
   <summary><b>Java workflow code</b></summary>

Open the `ChainingWorkflow.java` file located in the `/src/main/java/io/dapr/springboot/examples/chain/` folder. This file contains the workflow code.

The workflow has an `input` of type `String`. This input is used as the input for the first activity. Each activity output is used as the input for the next activity. The output of the last activity is returned as the workflow output.

</details>

<details>
   <summary><b>.Python workflow code</b></summary>

Open the `chaining_workflow.py` file located in the `task_chaining` folder. This file contains the workflow code.

The workflow has an `wf_input` of type `str`. This `wf_input` is used as the input for the first activity. Each activity output is used as the input for the next activity. The output of the last activity is returned as the workflow output.

</details>

### 1.3. Inspect the Activity code

> [!NOTE]
> Expand the language-specific instructions to inspect the activities.

<details>
   <summary><b>.NET activity code</b></summary>

The three activity definitions are located in the `TaskChaining/Activities` folder. All activities append a word to the input.

</details>

<details>
   <summary><b>Java activity code</b></summary>

The three activity definitions are located in the `src/main/java/io/dapr/springboot/examples/chain/` folder. All activities append a word to the input.

</details>

<details>
   <summary><b>Python activity code</b></summary>

The three activity definitions are located underneath the workflow in the `chaining_workflow.py` file. All activities append a word to the input.

</details>

### 1.4. Inspect the startup code

> [!NOTE]
> Expand the language-specific instructions to learn more about workflow registration, workflow runtime startup, and HTTP endpoints to start the workflow.

<details>
   <summary><b>.NET registration and endpoints</b></summary>

Locate the `Program.cs` file in the `TaskChaining` folder. This file contains the code to register the workflow and activities using the `AddDaprWorkflow()` extension method.

This application also has a `start` HTTP POST endpoint that is used to start the workflow.

</details>

<details>
   <summary><b>Java endpoints</b></summary>

Locate the `TaskChainingRestController.java` file in the `/src/main/java/io/dapr/springboot/examples` folder. This file contains two HTTP endpoints:

- A `start` HTTP POST endpoint that is used to schedule the workflow.
- A `output` HTTP GET endpoint that is used to check the status of the workflow.

</details>

<details>
   <summary><b>Python workflow runtime and endpoints</b></summary>

Locate the `app.py` file in the `task_chaining` folder. This file contains the code to start the workflow runtime and a `start` HTTP endpoint to start the workflow.

</details>

## 2. Run the workflow app

> [!NOTE]
> Expand the language-specific instructions to start the workflow application.

<details>
   <summary><b>Run the .NET application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *csharp/task-chaining* folder:

```bash,run
cd csharp/task-chaining
```

Install the dependencies and build the project:

```bash,run
dotnet build TaskChaining
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the Java application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/task-chaining* folder:

```bash,run
cd java/task-chaining
```

Build and run the application using Maven:

```bash,run
mvn spring-boot:test-run
```

</details>

<details>
   <summary><b>Run the Python application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/task-chaining/task_chaining* folder:

```bash,run
cd python/task-chaining/task_chaining
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
> Expand the language-specific instructions to start the chaining workflow.

<details>
   <summary><b>Start the .NET workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST \
  --url http://localhost:5255/start \
  -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\r\n')
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - chaining == activity1: Received input: This.
== APP - chaining == activity2: Received input: This is.
== APP - chaining == activity3: Received input: This is task.
```

</details>

<details>
   <summary><b>Start the Java workflow</b></summary>

In the **curl** window, run the following command to start the workflow:

```curl,run
curl -i --request POST http://localhost:8080/start
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
io.dapr.workflows.WorkflowContext        : Starting Workflow: io.dapr.springboot.examples.chain.ChainingWorkflow
i.d.springboot.examples.chain.Activity1  : io.dapr.springboot.examples.chain.Activity1 : Received input: This
i.d.springboot.examples.chain.Activity2  : io.dapr.springboot.examples.chain.Activity2 : Received input: This is
i.d.springboot.examples.chain.Activity3  : io.dapr.springboot.examples.chain.Activity3 : Received input: This is task
```

</details>

<details>
   <summary><b>Start the Python workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST --url http://localhost:5255/start \
  -i | grep -o '"instance_id":"[^"]*"' \
   | sed 's/"instance_id":"//;s/"//g' \
   | tr -d '\r\n')
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - chaining == Activity1: Received input: This.
== APP - chaining == Activity2: Received input: This is.
== APP - chaining == Activity3: Received input: This is task.
```

</details>

## 4. Get the workflow status

Use the **curl** window to perform a GET request directly the Dapr workflow management API to retrieve the workflow status.

> [!NOTE]
> Expand the language-specific instructions to get the workflow instance status.

<details>
   <summary><b>Get the .NET workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3555/v1.0/workflows/dapr/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "instanceID":"<INSTANCE_ID>",
   "workflowName":"ChainingWorkflow",
   "createdAt":"2025-04-17T12:04:53.094038635Z",
   "lastUpdatedAt":"2025-04-17T12:04:53.380547765Z",
   "runtimeStatus":"COMPLETED",
   "properties": {
      "dapr.workflow.input":"\"This\"",
      "dapr.workflow.output":"\"This is task chaining\""
   }
}
```

</details>

<details>
   <summary><b>Get the Java workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:8080/output
```

Expected output:

```text
This is task chaining
```

</details>

<details>
   <summary><b>Get the Python workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3555/v1.0/workflows/dapr/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "instanceID":"<INSTANCE_ID>",
   "workflowName":"chaining_workflow",
   "createdAt":"2025-04-17T12:04:53.094038635Z",
   "lastUpdatedAt":"2025-04-17T12:04:53.380547765Z",
   "runtimeStatus":"COMPLETED",
   "properties": {
      "dapr.workflow.input":"\"This\"",
      "dapr.workflow.output":"\"This is task chaining\""
   }
}
```

</details>

## 5. Stop the workflow application

Use the **Dapr CLI** window to stop the workflow application by pressing `Ctrl+C`.

---

You've now seen how to use the task chaining pattern in a workflow application. Let's move on another pattern: *fan-out/fan-in*.
