In this challenge, you'll explore a workflow application that demonstrates how to call child workflows from a parent workflow.

## 1. Child Workflows

Workflows can call other workflows, which are referred to as child workflows. This allows the creation of complex workflows by composing smaller, reusable workflows, which can be individually tested.

![Child Workflows](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/7-child-workflows/images/dapr-uni-wf-child-workflow-v1.png?raw=true)

The parent workflow in this challenge uses the fan-out/fan-in pattern to call multiple child workflows in parallel.

- The workflow is started with an array of strings as the input argument.
- For each string in the input array, a child workflow task is created.
- Each child workflow uses task chaining to call two activities.
- The parent workflow waits for all child workflows to complete and aggregates the results into a single result.

![Child Workflow Demo](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/7-child-workflows/images/dapr-uni-wf-child-workflow-demo-v1.png?raw=true)

### 1.1 Choose a language tab

Use one of the language tabs to navigate to the child workflow example. Each language tab contains a workflow application, and a Multi-App Run `dapr.yaml` file that is used to run the example.

### 1.2 Inspect the parent workflow code

> [!NOTE]
> Expand the language-specific instructions to learn more about the parent workflow.

<details>
   <summary><b>.NET parent workflow</b></summary>

Open the `ParentWorkflow.cs` file located in the `ChildWorkflows` folder. This file contains the code for the parent workflow.

The `CallChildWorkflowAsync` method is used to call the child workflow. The first argument is the name of the child workflow, and the second argument is the input for the child workflow.

```csharp,nocopy
foreach (string item in input)
{
   childWorkflowTasks.Add(context.CallChildWorkflowAsync<string>(
      nameof(ChildWorkflow),
      item));
}
```

</details>

<details>
   <summary><b>Python parent workflow</b></summary>

Open the `parent_child_workflow.py` file located in the `child_workflows` folder. This file contains the code for the `parent_workflow`.

The `call_child_workflow` method on the `DaprWorkflowContext` is used to call the `child_workflow`. The first argument is the name of the child workflow, and the second argument is the input for the child workflow.

```python,nocopy
child_wf_tasks = [
        ctx.call_child_workflow(child_workflow, input=item) for item in items
    ]
```

</details>

### 1.3 Inspect the child workflow code

> [!NOTE]
> Expand the language-specific instructions to learn more about the child workflow.

<details>
   <summary><b>.NET child workflow</b></summary>

Open the `ChildWorkflow.cs` file located in the `ChildWorkflows` folder. This file contains the code for the child workflow. This workflow uses task chaining to call two activities, `Activity1` and `Activity2`, in sequence.

</details>

<details>
   <summary><b>Python child workflow</b></summary>

Open the `parent_child_workflow.py` file located in the `child_workflows` folder. This file contains the code for the `child_workflow` located below the `parent_workflow`. This workflow uses task chaining to call two activities, `activity1` and `activity2`, in sequence.

</details>

### 1.4. Inspect the startup code

> [!NOTE]
> Expand the language-specific instructions to learn more about workflow registration, workflow runtime startup, and HTTP endpoints to start the workflow.

<details>
   <summary><b>.NET registration and endpoints</b></summary>

Locate the `Program.cs` file in the `ChildWorkflows` folder. This file contains the code to register the workflows and activities using the `AddDaprWorkflow()` extension method.

This application also has a `start` HTTP POST endpoint that is used to start the workflow, and accepts an array of string as the input.

</details>

<details>
   <summary><b>Python workflow runtime and endpoints</b></summary>

Locate the `app.py` file in the `child_workflows` folder. This file contains the code to start the workflow runtime and a `start` HTTP endpoint to start the workflow.

</details>

## 2. Run the workflow app

> [!NOTE]
> Expand the language specific instructions to start the child workflow application.

<details>
   <summary><b>Run the .NET application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *csharp/child-workflows* folder:

```bash,run
cd csharp/child-workflows
```

Install the dependencies and build the project:

```bash,run
dotnet build ChildWorkflows
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the Python application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/child-workflows/child_workflows* folder:

```bash,run
cd python/child-workflows/child_workflows
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
> Expand the language-specific instructions to start the external system interaction workflow.

<details>
   <summary><b>Start the .NET workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST \
  --url http://localhost:5259/start \
  --header 'content-type: application/json' \
  --data '["Item 1","Item 2"]' \
  -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\r\n')
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - childworkflows == Activity1: Received input: Item 2.
== APP - childworkflows == Activity1: Received input: Item 1.
== APP - childworkflows == Activity2: Received input: Item 1 is processed.
== APP - childworkflows == Activity2: Received input: Item 2 is processed.
```

> [!NOTE]
> The order of the log statements may vary, as the child workflows are executed in parallel.

</details>

<details>
   <summary><b>Start the Python workflow</b></summary>

In the **curl** window, run the following command to start the workflow and capture the workflow instance ID:

```curl,run
INSTANCEID=$(curl -s --request POST \
  --url http://localhost:5259/start \
  --header 'content-type: application/json' \
  --data '["Item 1","Item 2"]' \
  -i | grep -o '"instance_id":"[^"]*"' \
   | sed 's/"instance_id":"//;s/"//g' \
   | tr -d '\r\n')
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - childworkflows == activity1: Received input: Item 2.
== APP - childworkflows == activity1: Received input: Item 1.
== APP - childworkflows == activity2: Received input: Item 1 is processed.
== APP - childworkflows == activity2: Received input: Item 2 is processed.
```

> [!NOTE]
> The order of the log statements may vary, as the child workflows are executed in parallel.

</details>

## 4. Get the workflow status

Use the **curl** window to perform a GET request directly the Dapr workflow management API to retrieve the workflow status.

> [!NOTE]
> Expand the language-specific instructions to get the workflow instance status.

<details>
   <summary><b>Get the .NET workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3559/v1.0/workflows/dapr/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "instanceID":"<INSTANCE_ID>",
   "workflowName":"ParentWorkflow",
   "createdAt":"2025-04-22T13:39:06.694524219Z",
   "lastUpdatedAt":"2025-04-22T13:39:06.994152799Z",
   "runtimeStatus":"COMPLETED",
   "properties":{
      "dapr.workflow.input":"[\"Item 1\",\"Item 2\"]",
      "dapr.workflow.output":"[\"Item 1 is processed as a child workflow.\",\"Item 2 is processed as a child workflow.\"]"
   }
}
```

</details>

<details>
   <summary><b>Get the Python workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3559/v1.0/workflows/dapr/$INSTANCEID
```

Where `$INSTANCEID` is the environment variable containing the workflow instance ID captured in the previous step.

Expected output:

```json,nocopy
{
   "instanceID":"<INSTANCE_ID>",
   "workflowName":"parent_workflow",
   "createdAt":"2025-04-22T13:39:06.694524219Z",
   "lastUpdatedAt":"2025-04-22T13:39:06.994152799Z",
   "runtimeStatus":"COMPLETED",
   "properties":{
      "dapr.workflow.input":"[\"Item 1\",\"Item 2\"]",
      "dapr.workflow.output":"[\"Item 1 is processed as a child workflow.\",\"Item 2 is processed as a child workflow.\"]"
   }
}
```

</details>

## 5. Stop the workflow application

Use the **Dapr CLI** window to stop the workflow application by pressing `Ctrl+C`.

---

You now know how to compose a parent workflow from smaller child workflows. Now, let's have a look at resiliency and compensation in workflows.
