In this challenge you'll build the brains of the USS Enterprise diagnostics: a Dapr Workflow that fans out to three subsystem activities in parallel, aggregates the results into a prioritized report, and conditionally notifies the bridge. You'll define the data models, the workflow, three activities, and register everything in the API service.

Now that the Aspire solution is scaffolded and dependencies are available, the code for the workflow, activities, and models can be added. All workflow related files will live in the `EnterpriseDiagnostics.ApiService/` project.

## 1. Folder creation

Navigate to the  `EnterpriseDiagnostics/` path:

```shell, run,copy
cd EnterpriseDiagnostics
```

Create the following folders using the *Terminal*:

```shell,run,copy
mkdir EnterpriseDiagnostics.ApiService/Models
mkdir EnterpriseDiagnostics.ApiService/Workflows
mkdir EnterpriseDiagnostics.ApiService/Activities
```

Refresh the *Editor* window afterwards so you see the new folders.

## 2. Models — `Models/Models.cs`

Create the models first, they are all `record` type and placed in the same `Models.cs` file. There are input and output records for the workflow, the subsystem diagnostics the prioritization, and the bridge notification activities.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Models/Models.cs
```

Then copy the model code into the file:

```csharp,copy
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

## 3. Workflow — `Workflows/EnterpriseDiagnosticsWorkflow.cs`

Now create the workflow, it will fan-out/fan-in over 3 subsystems to run diagnostics, then prioritize, then conditionally notify the bridge.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Workflows/EnterpriseDiagnosticsWorkflow.cs
```

Then copy the workflow code into the file:

```csharp,copy
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

## 4. Activity — `Activities/DiagnoseSubsystemActivity.cs`

Now create the DiagnoseSubsystemActivity, it returns randomly-generated mock telemetry for a single subsystem.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Activities/DiagnoseSubsystemActivity.cs
```

Then copy the activity code into the file:

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

## 5. Activity — `Activities/PrioritizeDiagnosticsActivity.cs`

Create the PrioritizeDiagnosticsActivity which aggregates the three subsystem reports into a single prioritized report.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Activities/PrioritizeDiagnosticsActivity.cs
```

Then copy the activity code into the file:

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

## 6. Activity — `Activities/NotifyBridgeActivity.cs`

Create the final activity, NotifyBridgeActivity, that mock-notifies the bridge with a randomly chosen acknowledging officer.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Activities/NotifyBridgeActivity.cs
```

Then copy the activity code into the file:

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

Run a `dotnet build` to verify to solution builds correctly.

```shell,run,copy
dotnet build
```

## 7. Update `EnterpriseDiagnostics.ApiService/Program.cs`

Replace the file contents with:

```csharp,copy
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

app.MapPost("pause/{instanceId}", async (
    [FromRoute] string instanceId,
    [FromServices] DaprWorkflowClient workflowClient) =>
{
    await workflowClient.SuspendWorkflowAsync(instanceId);
    return Results.Accepted();
});

app.MapPost("resume/{instanceId}", async (
    [FromRoute] string instanceId,
    [FromServices] DaprWorkflowClient workflowClient) =>
{
    await workflowClient.ResumeWorkflowAsync(instanceId);
    return Results.Accepted();
});

app.MapPost("terminate/{instanceId}", async (
    [FromRoute] string instanceId,
    [FromServices] DaprWorkflowClient workflowClient) =>
{
    await workflowClient.TerminateWorkflowAsync(instanceId);
    return Results.Accepted();
});

app.MapDefaultEndpoints();

app.Run();
```

> [!IMPORTANT]
> Workflow types are auto-registered by `AddDaprWorkflowVersioning()` — only activities need explicit `RegisterActivity<T>()` calls.

## 8. Verify

From the solution root perform a dotnet build:

```shell,run,copy
dotnet build EnterpriseDiagnostics.sln
```

Fix any errors before continuing. Don't run the Aspire solution yet since you need to configure the statestore that is required for the workflow.

---

You now have a complete Dapr Workflow with three activities and a fully wired API service. The workflow runs three subsystem diagnostics in parallel, aggregates them into a prioritized report, and conditionally notifies the bridge — all that's missing is the state store and AppHost wiring to actually run it.
