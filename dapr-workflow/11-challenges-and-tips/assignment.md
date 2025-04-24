# Challenges and Tips

In this final challenge, you'll explore common challenges that workflow as code systems have and how to deal with them.

## 1. Challenges and Tips

Workflows are great tools to ensure durable execution of your code, but they also have their limitations. This challenge covers:

- Deterministic workflows
- Idempotent activities
- Workflow versioning
- Payload size

### 1.1 Choose a language tab

Use one of the language tabs to navigate to the code. Each language tab contains several code files to illustrate the challenges and tips.

### 1.2 Deterministic workflows

Workflows should be deterministic. This means that if a workflow is run multiple times with the same input, it should result in the same workflow output. This is important because a workflow will be replayed several times during its lifetime. If the workflow is not deterministic, there could be a mismatch between the workflow state in the state store and the workflow state during runtime. This could lead to unexpected behavior and errors.

Workflow code should only consist of activity calls and control logic such as if/else statements and try/catch blocks. It's important to wrap any non-deterministic code in an activity.

*Use the language-specific instructions to inspect the workflow code.*

<details>
   <summary><b>.NET</b></summary>

Navigate to the `DeterministicWorkflow.cs` file. It contains two workflows: `NonDeterministicWorkflow` and `DeterministicWorkflow`. The `NonDeterministicWorkflow` uses unsafe code that is not deterministic. The `DeterministicWorkflow` uses the `WorkflowContext` to create a GUID and a `DateTime` and is safe.

> [!WARNING]
> Do not create GUIDs, random numbers, or `DateTime` objects in the workflow code.

The `WorkflowContext` contains helper methods to create new GUIDs and `DateTime`s that are safe for replay:

```csharp
var replaySafeGuid = context.NewGuid();
var replaySafeDateTime = context.CurrentUtcDateTime;
```

</details>

### 1.3. Idempotent activities

Dapr Workflow guarantees at-least-once execution of activities, so activities might be executed more than once in case an activity is not run to completion successfully. Always check your activity code if it's safe to be executed multiple times without unwanted side effects. If the activity can be executed multiple times without side effects, it is idempotent.

For instance, when the activity inserts a record into a database and the activity code is providing the primary key of the record, can the activity be executed multiple times without creating database exceptions? It might be safer to do an upsert operation instead of an insert operation. Or first try a read operation, and if the record does not exist, perform an insert operation.

> [!IMPORTANT]
> Always check if the APIs that are used in the activity code provide idempotent operations.

### 1.4. Payload size

Workflows as code are likely to undergo changes over time. These changes can cause issues when the workflow state in the state store of unfinished (or in-flight) workflows is no longer compatible with the new workflow code.

One way to deal with breaking changes is to use workflow name versioning. This means that instead of updating the workflow code, a new workflow is created, and a version number is added to the workflow name: `WorkflowClassV1`, `WorkflowClassV2`, etc. Once the application is deployed with the new workflow version, all the in-flight workflows can be replayed safely and completed with the old workflow. Note that this solution does require that the clients that manage the workflow need to be updated to use the new workflow version.

*Use the language-specific instructions to inspect the workflow code.*

<details>
   <summary><b>.NET</b></summary>

Navigate to the `VersioningWorkflow.cs` file. It contains two workflows: `VersioningWorkflow1` and `VersioningWorkflow2`. Inspect these workflows and note the breaking change due to the input arguments for the activities.

</details>

### 1.5. Workflow versioning

The Dapr Workflow engine is continuously interacting with both the workflow application and the state store to pass input and output data back and forth. It is important to keep the input and output of workflows and especially activities small to prevent serializing/deserializing many large objects, which can degrade performance.

When a workflow is using task chaining for many activities and the output of one activity is used as the input for the next activity, that object is persisted twice. Once as the output of the first activity and once as the input of the second activity. So ensure that this object is as small as possible.

> [!IMPORTANT]
> Preferably, pass IDs as input arguments to an activity, so the activity can fetch the data, update it, and save it all in one activity. And be selective in what data is passed back to the workflow.

*Use the language-specific instructions to inspect the workflow code.*

<details>
   <summary><b>.NET</b></summary>

Navigate to the `PayloadSizeWorkflow.cs` file. It contains two workflows: `LargePayloadSizeWorkflow` and `SmallPayloadSizeWorkflow`. Inspect these workflows and note the difference in activity usage.

</details>

---

Congratulations! You've completed the Dapr University workflow learning track!

All code samples shown in this Dapr University track are available in the [Dapr QuickStarts](https://github.com/dapr/quickstarts/) repository in the `tutorials/workflow` folder. Give this repo a star and clone it locally to use it as reference material for building your next workflow project.

If you want to quickly build workflows based on a workflow diagram, take a look at [Diagrid Workflow Composer](). You can upload a workflow image, select the language, and this tool will generate a scaffolded Dapr workflow project that you can download and use as a starting point.
