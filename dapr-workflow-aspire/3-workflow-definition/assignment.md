In this challenge you'll build the brains of the USS Enterprise diagnostics: a Dapr Workflow that fans out to three subsystem activities in parallel, aggregates the results into a prioritized report, and conditionally notifies the bridge. You'll define the three activities, the data models, the workflow, and register everything in the API service.

This is the visual representation of the workflow you'll build:
![enterprise-diagnostics-workflow (1).png](https://play.instruqt.com/assets/tracks/kyfkrd3ggejg/5314b2be2a3ae34ebccd3b2b58256dd3/assets/enterprise-diagnostics-workflow%20(1).png)

## 1. Folder & file creation

All the workflow related code will be created in the ApiService project.

1. Create the following folders using the *Terminal* (ensure you're in the *EnterpriseDiagnostics* folder):

```shell,run,copy
mkdir EnterpriseDiagnostics.ApiService/Models
mkdir EnterpriseDiagnostics.ApiService/Workflows
mkdir EnterpriseDiagnostics.ApiService/Activities
```

2. Create the following empty files for the models, workflow and the activities:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Models/Models.cs
touch EnterpriseDiagnostics.ApiService/Workflows/EnterpriseDiagnosticsWorkflow.cs
touch EnterpriseDiagnostics.ApiService/Activities/DiagnoseSubsystemActivity.cs
touch EnterpriseDiagnostics.ApiService/Activities/PrioritizeDiagnosticsActivity.cs
touch EnterpriseDiagnostics.ApiService/Activities/NotifyBridgeActivity.cs
```

3. Refresh the *Editor* window afterwards so you see the new folders & (empty) files in the ApiService project.

## 2. Activities

You'll create three activities that the workflow will call: `DiagnoseSubsystemActivity` runs (mock) diagnostics for a single subsystem and is invoked once per subsystem in parallel, `NotifyBridgeActivity` mock-notifies the bridge when priority is urgent, and `PrioritizeDiagnosticsActivity` aggregates the three subsystem reports into a single prioritized report.

> [!NOTE]
> The activities reference model types (`SubsystemDiagnosticsInput`, etc.) that you'll add in section 3, so expect compile errors in the *Editor* until you've finished section 3. The project is only built at the *Verify* step.

### 2.1 DiagnoseSubsystemActivity.cs

The `DiagnoseSubsystemActivity` returns randomly-generated mock telemetry for a single subsystem.

1. Use the *Editor* and navigate to the `DiagnoseSubsystemActivity.cs` file in the `EnterpriseDiagnostics.ApiService/Activities/` folder.
2. Copy the activity code into the file:

```csharp,copy
using Microsoft.Extensions.Logging;
using Dapr.Workflow;
using EnterpriseDiagnostics.Models;

namespace EnterpriseDiagnostics.Activities;

internal sealed partial class DiagnoseSubsystemActivity(ILogger<DiagnoseSubsystemActivity> logger)
    : WorkflowActivity<SubsystemDiagnosticsInput, SubsystemDiagnosticsOutput>
{
    private static readonly string[] Statuses = ["Nominal", "Degraded", "Critical"];

    public override Task<SubsystemDiagnosticsOutput> RunAsync(
        WorkflowActivityContext context,
        SubsystemDiagnosticsInput input)
    {
        LogDiagnosing(logger, input.SubsystemName);

        var random = Random.Shared;
        var status = Statuses[random.Next(Statuses.Length)];
        var anomalyScore = random.Next(0, 101);
        var powerLevel = Math.Round(random.NextDouble() * 100.0, 2);

        var result = new SubsystemDiagnosticsOutput(
            input.SubsystemName,
            status,
            anomalyScore,
            powerLevel);

        LogDiagnosed(logger, input.SubsystemName, status, anomalyScore);
        return Task.FromResult(result);
    }

    [LoggerMessage(LogLevel.Information, "Diagnosing subsystem {Subsystem}")]
    static partial void LogDiagnosing(ILogger logger, string Subsystem);

    [LoggerMessage(LogLevel.Information, "Diagnosed {Subsystem}: status={Status}, anomaly={Anomaly}")]
    static partial void LogDiagnosed(ILogger logger, string Subsystem, string Status, int Anomaly);
}
```

This activity inherits from `WorkflowActivity<TInput, TOutput>`, the Dapr base class for activity classes. The `RunAsync` method is the entry point the Dapr Workflow engine invokes when the workflow schedules this activity. Unlike workflow code, activities are allowed to use non-deterministic constructs (`Random.Shared`, `DateTime.Now`, file/network I/O) — the engine records each activity's result the first time it runs and reuses that result on replay, so the non-determinism never affects the durable history.

### 2.2 NotifyBridgeActivity.cs

The `NotifyBridgeActivity` mock-notifies the bridge with a randomly chosen acknowledging officer.

1. Use the *Editor* and navigate to the `NotifyBridgeActivity.cs` file located in the `EnterpriseDiagnostics.ApiService/Activities/` folder.
2. Copy the activity code into the file:

```csharp,copy
using Microsoft.Extensions.Logging;
using Dapr.Workflow;
using EnterpriseDiagnostics.Models;

namespace EnterpriseDiagnostics.Activities;

internal sealed partial class NotifyBridgeActivity(ILogger<NotifyBridgeActivity> logger)
    : WorkflowActivity<BridgeNotificationInput, BridgeNotificationOutput>
{
    private static readonly string[] Officers =
    [
        "Capt. Picard",
        "Cmdr. Riker",
        "Lt. Cmdr. Data",
        "Lt. Worf",
    ];

    public override Task<BridgeNotificationOutput> RunAsync(
        WorkflowActivityContext context,
        BridgeNotificationInput input)
    {
        var officer = Officers[Random.Shared.Next(Officers.Length)];
        LogNotify(logger, input.Priority, officer);

        return Task.FromResult(new BridgeNotificationOutput(
            Acknowledged: true,
            AcknowledgedBy: officer));
    }

    [LoggerMessage(LogLevel.Warning, "Bridge notified ({Priority}); acknowledged by {Officer}")]
    static partial void LogNotify(ILogger logger, string Priority, string Officer);
}
```

The structure is identical to the previous activity: a `WorkflowActivity<TInput, TOutput>` subclass with a single `RunAsync` method. The workflow only calls this activity when the prioritized diagnostics escalate to **Urgent**, which is why the notification is logged at `Warning` level — making it easy to spot in the Aspire dashboard logs.

### 2.3 PrioritizeDiagnosticsActivity.cs

The `PrioritizeDiagnosticsActivity` aggregates the three subsystem reports into a single prioritized report.

1. Use the *Editor* and navigate to the `PrioritizeDiagnosticsActivity.cs` file in the `EnterpriseDiagnostics.ApiService/Activities/` folder.
2. Then copy the activity code into the file:

```csharp,copy
using Microsoft.Extensions.Logging;
using Dapr.Workflow;
using EnterpriseDiagnostics.Models;

namespace EnterpriseDiagnostics.Activities;

internal sealed partial class PrioritizeDiagnosticsActivity(ILogger<PrioritizeDiagnosticsActivity> logger)
    : WorkflowActivity<PrioritizationInput, PrioritizationOutput>
{
    public override Task<PrioritizationOutput> RunAsync(
        WorkflowActivityContext context,
        PrioritizationInput input)
    {
        var maxAnomaly = input.Diagnostics.Max(a => a.AnomalyScore);
        var anyCritical = input.Diagnostics.Any(a => a.Status == "Critical");

        string priority = (anyCritical, maxAnomaly) switch
        {
            (true, _) => "Urgent",
            (false, >= 70) => "Urgent",
            (false, >= 40) => "Warning",
            _ => "Normal",
        };

        var summary = string.Join("; ",
            input.Diagnostics.Select(a =>
                $"{a.SubsystemName}={a.Status} (anomaly {a.AnomalyScore}, power {a.PowerLevel}%)"));

        LogPriority(logger, priority, maxAnomaly);
        return Task.FromResult(new PrioritizationOutput(priority, summary));
    }

    [LoggerMessage(LogLevel.Information, "Prioritized diagnostics: {Priority} (max anomaly={Max})")]
    static partial void LogPriority(ILogger logger, string Priority, int Max);
}
```

Activities aren't limited to external, non-deterministic calls — they can also do pure compute, as this one does. The switch expression with tuple patterns assigns a priority based on whether any subsystem reported `Critical` and how high the maximum anomaly score is. The resulting `priority` and `summary` flow back to the workflow as a `PrioritizationOutput` record and drive the conditional bridge notification.

## 3. Models — `Models/Models.cs`

Now add the models. They are all `record` types and placed in the same `Models.cs` file. There are input and output records for the workflow, the subsystem diagnostics, the prioritization, and the bridge notification activities.

1. Use the *Editor* and navigate to the `Models.cs` file located in `EnterpriseDiagnostics.ApiService/Models/`:
2. Copy the model code into the file:

```csharp,copy,wrap
namespace EnterpriseDiagnostics.Models;

public record EnterpriseDiagnosticsInput(string Id, string StarDate);

public record EnterpriseDiagnosticsOutput(
    string StarDate,
    string Priority,
    string Summary,
    bool BridgeNotified);

public record SubsystemDiagnosticsInput(string SubsystemName);

public record SubsystemDiagnosticsOutput(
    string SubsystemName,
    string Status,
    int AnomalyScore,
    double PowerLevel);

public record PrioritizationInput(SubsystemDiagnosticsOutput[] Diagnostics);

public record PrioritizationOutput(string Priority, string Summary);

public record BridgeNotificationInput(string Priority, string Summary);

public record BridgeNotificationOutput(bool Acknowledged, string AcknowledgedBy);
```

Records are used throughout because they are immutable and serialize cleanly to JSON. The Dapr Workflow engine serializes every workflow input/output and every activity input/output to the configured state store, so all types crossing those boundaries must be JSON-serializable. Each activity in this workflow has its own input/output pair, plus a top-level pair (`EnterpriseDiagnosticsInput` / `EnterpriseDiagnosticsOutput`) for the workflow itself.

## 4. Workflow — `Workflows/EnterpriseDiagnosticsWorkflow.cs`

Now create the workflow, it will fan-out/fan-in over 3 subsystems to run diagnostics, then prioritize, then conditionally notify the bridge.

1. Use the *Editor* and navigate to the `EnterpriseDiagnosticsWorkflow.cs` file located in `EnterpriseDiagnostics.ApiService/Workflows/`.
2. Copy the workflow code into the file:

```csharp,copy,wrap
using Microsoft.Extensions.Logging;
using Dapr.Workflow;
using EnterpriseDiagnostics.Activities;
using EnterpriseDiagnostics.Models;

namespace EnterpriseDiagnostics.Workflows;

internal sealed partial class EnterpriseDiagnosticsWorkflow
    : Workflow<EnterpriseDiagnosticsInput, EnterpriseDiagnosticsOutput>
{
    private static readonly string[] Subsystems =
    [
        "WarpDrive",
        "LifeSupport",
        "Shields",
    ];

    public override async Task<EnterpriseDiagnosticsOutput> RunAsync(
        WorkflowContext context,
        EnterpriseDiagnosticsInput input)
    {
        var logger = context.CreateReplaySafeLogger<EnterpriseDiagnosticsWorkflow>();
        LogStart(logger, context.InstanceId, input.StarDate);

        // Prepare the activity calls, they are *not* sent to the workflow engine yet.
        var diagnosticsTasks = Subsystems.Select(name =>
            context.CallActivityAsync<SubsystemDiagnosticsOutput>(
                nameof(DiagnoseSubsystemActivity),
                new SubsystemDiagnosticsInput(name)));

        // All activity tasks are sent to the workflow engine.
        // The workflow will wait until all are completed.
        var diagnostics = await Task.WhenAll(diagnosticsTasks);

        var prioritization = await context.CallActivityAsync<PrioritizationOutput>(
            nameof(PrioritizeDiagnosticsActivity),
            new PrioritizationInput(diagnostics));

        bool bridgeNotified = false;
        if (string.Equals(prioritization.Priority, "Urgent", StringComparison.OrdinalIgnoreCase))
        {
            LogUrgent(logger, context.InstanceId);
            var notification = await context.CallActivityAsync<BridgeNotificationOutput>(
                nameof(NotifyBridgeActivity),
                new BridgeNotificationInput(prioritization.Priority, prioritization.Summary));
            bridgeNotified = notification.Acknowledged;
        }

        return new EnterpriseDiagnosticsOutput(
            input.StarDate,
            prioritization.Priority,
            prioritization.Summary,
            bridgeNotified);
    }

    [LoggerMessage(LogLevel.Information, "Starting diagnostics workflow {Id} at stardate {StarDate}")]
    static partial void LogStart(ILogger logger, string Id, string StarDate);

    [LoggerMessage(LogLevel.Warning, "Urgent priority detected on workflow {Id}; notifying bridge")]
    static partial void LogUrgent(ILogger logger, string Id);
}
```

The workflow inherits `Workflow<TInput, TOutput>` and its `RunAsync` is the entry point. A few important details:

- `context.CreateReplaySafeLogger` is used instead of an injected `ILogger` because workflows replay after each activity call or timer; the replay-safe logger suppresses duplicate log lines for already-recorded events.
- `context.CallActivityAsync<T>(nameof(Activity), input)` does **not** call the activity directly. It schedules an activity execution with the workflow engine, and the workflow durably awaits the result.
- Building `diagnosticsTasks` with `Select(...)` and then awaiting `Task.WhenAll` is the **fan-out / fan-in** pattern: the three subsystem diagnostics run in parallel and the workflow continues once all three complete.
- Workflow code must be deterministic — no `DateTime.Now`, `Random`, file or network I/O. Anything non-deterministic belongs inside an activity.

## 5. Update `EnterpriseDiagnostics.ApiService/Program.cs`

1. Use the *Editor* and navigate to the `Program.cs` file located in `EnterpriseDiagnostics.ApiService/`.
2. Replace the file contents with:

```csharp,copy,wrap
using Microsoft.AspNetCore.Mvc;
using Dapr.Workflow;
using Dapr.Workflow.Versioning;
using EnterpriseDiagnostics.Activities;
using EnterpriseDiagnostics.Models;
using EnterpriseDiagnostics.Workflows;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

builder.Services.AddDaprWorkflow(options =>
{
    options.RegisterActivity<DiagnoseSubsystemActivity>();
    options.RegisterActivity<PrioritizeDiagnosticsActivity>();
    options.RegisterActivity<NotifyBridgeActivity>();
});
builder.Services.AddDaprWorkflowVersioning();

var app = builder.Build();

app.MapPost("/start", async (
    [FromServices] DaprWorkflowClient workflowClient,
    [FromBody] EnterpriseDiagnosticsInput workflowInput) =>
{
    var instanceId = await workflowClient.ScheduleNewWorkflowAsync(
        name: nameof(EnterpriseDiagnosticsWorkflow),
        instanceId: workflowInput.Id,
        input: workflowInput);

    return Results.Ok(new { instanceId });
});

app.MapGet("/status/{instanceId}", async (
    [FromRoute] string instanceId,
    [FromServices] DaprWorkflowClient workflowClient) =>
{
    var state = await workflowClient.GetWorkflowStateAsync(instanceId);
    if (state is null || !state.Exists)
    {
        return Results.NotFound($"Workflow instance '{instanceId}' not found.");
    }

    var output = state.ReadOutputAs<EnterpriseDiagnosticsOutput>();
    return Results.Ok(new { state, output });
});

app.MapPost("/pause/{instanceId}", async (
    [FromRoute] string instanceId,
    [FromServices] DaprWorkflowClient workflowClient) =>
{
    await workflowClient.SuspendWorkflowAsync(instanceId);
    return Results.Accepted();
});

app.MapPost("/resume/{instanceId}", async (
    [FromRoute] string instanceId,
    [FromServices] DaprWorkflowClient workflowClient) =>
{
    await workflowClient.ResumeWorkflowAsync(instanceId);
    return Results.Accepted();
});

app.MapPost("/terminate/{instanceId}", async (
    [FromRoute] string instanceId,
    [FromServices] DaprWorkflowClient workflowClient) =>
{
    await workflowClient.TerminateWorkflowAsync(instanceId);
    return Results.Accepted();
});

app.MapDefaultEndpoints();

app.Run();
```

Two registration calls do the heavy lifting: `AddDaprWorkflow(...)` wires the Dapr Workflow runtime into DI and is where activities are registered, and `AddDaprWorkflowVersioning()` auto-discovers the workflow types themselves and enables workflow versioning support. The five HTTP endpoints expose the workflow management API end-to-end: start a new workflow, query its state, pause it, resume it, and terminate it. `DaprWorkflowClient` is resolved from DI and is the standard entry point for all workflow operations.

## 6. Verify

From the solution root perform a dotnet build:

```shell,run,copy
dotnet build
```

Fix any errors before continuing. Don't run the Aspire solution yet since you need to configure the statestore that is required for the workflow.

---

You now have a complete Dapr Workflow with three activities and a fully wired API service. The workflow runs three subsystem diagnostics in parallel, aggregates them into a prioritized report, and conditionally notifies the bridge. In the next challenge you'll configure the workflow state store and AppHost wiring to actually run the solution.
