# Dapr Workflow Fundamentals

**In this challenge, you'll learn how to write Dapr workflows in code, how the workflow engine persist workflow state, and how workflows are started.**

The code you see in this Dapr University track is available in the [Dapr QuickStarts](https://github.com/dapr/quickstarts/) repository in the `tutorials/workflow` folder. If you want to explore more code samples for other Dapr APIs in this repo, you can do so after completing this track.

## 1. Workflows and Activities

Workflows are authored in code using the Dapr Workflow SDK. Workflows are composed of activities, which are the building blocks of a workflow. Activities typically contain code that performs one specific task, such as calling an external service, storing data in a state store, performing a calculation, or publishing a message.

![Workflow with activities]()

Workflows orchestrate the activities in a specific order. Workflow code typically contains calls to activities, and business logic (if/else statements) based on the outputs of activities, to determine which activity should be executed next. Workflow code should be deterministic, meaning that the same input, for either workflows or activities, should always result in the same output. Any non-deterministic code should be placed in an activity. More information about (non)deterministic code is covered in the 4th challenge of this Dapr University track.

### 1.1 Choose a language tab

Use one of the language tabs to navigate to the basic workflow example. Each language tab contains a workflow application, and a `dapr.yaml` file that is used to run the example in the next step.

### 1.2 Inspect the Workflow code

<details>
   <summary><b>.NET</b></summary>

Open the `BasicWorkflow.cs` file located in the `Basic` folder. This file contains the workflow code.

The `BasicWorkflow` class inherits from an abstract `Workflow` class provided by the Dapr Workflow SDK, the generic arguments specify the input and the output types of the workflow.

The `BasicWorkflow` overrides the `RunAsync` method from the base class. This method is the entry point of the workflow.

Workflows are asynchronous and return a `Task` object. In this case the return type is `Task<string>`.

The `WorkflowContext` input argument is provided by the Dapr Workflow package and contains properties and methods of the workflow instance. The second input argument is the input argument for the workflow.

You can use any type of input and output for the workflow, as long as they are serializable.

The body of the `RunAsync` method contains two calls to activities using the `CallActivityAsync` method. The generic argument defines the output type of the activity. The first input argument is the name of the activity, the second input argument is the input for the activity.

</details>

### 1.3 Inspect the Activity code

## 2. Starting and monitoring workflows

Use the language specific instructions to start the basic workflow.

<details>
   <summary><b>Run the .NET workflow</b></summary>

	Install the dependencies:

```bash
dotnet restore Basic
```

Run the applications using the Dapr CLI:

```bash
dapr run -f .
```
</details>


## 3. Workflow state and replay


---

You now know how Dapr workflows and activities are defines in code, how the workflow engine persist workflow state, and how to start a workflow and get their status. Let's continue with the various workflow patterns you can apply in your workflow applications.