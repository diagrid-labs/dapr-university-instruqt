# Write the workflow

In this lab, you'll write the diagnostics workflow and its three activities, and register them in the `Engineering` app. This hands-on lab takes about 8 minutes to complete.

## 1. The diagnostics workflow

> [!IMPORTANT]
> This lab continues from the previous lab: it adds code to the `MeridianDiagnostics` solution you created there.

A Dapr workflow has two kinds of code. The **workflow** decides which steps run and in what order. The **activities** do the actual work, such as reading a sensor. This is the workflow you'll write:

![DiagnosticsWorkflow fans out to three DiagnoseSubsystemActivity calls, for WarpCore, LifeSupport and Shields, and fans in when all three have reported. It then waits 15 seconds on a durable timer, runs PrioritizeDiagnosticsActivity, and calls NotifyBridgeActivity only when the priority is Urgent.](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow-aspire/2-write-the-workflow/images/workflow.png?raw=true)

1. **Fan-out/fan-in.** `DiagnosticsWorkflow` calls `DiagnoseSubsystemActivity` three times at once, for `WarpCore`, `LifeSupport` and `Shields`, and waits until all three have reported.
2. **Let the sensors settle.** It waits 15 seconds on a durable timer.
3. **Prioritize.** `PrioritizeDiagnosticsActivity` turns the three reports into one priority: `Urgent`, `Elevated` or `Routine`.
4. **Notify the bridge.** Only when the priority is `Urgent`, `NotifyBridgeActivity` notifies an officer on the bridge.

While the workflow runs, the Dapr sidecar saves every step in the workflow's history. When the app restarts, the workflow code runs again from the start, and every step that already finished returns its saved result instead of running again. This is called *replay*. It only works when the workflow code makes the same decisions every time it runs, so the workflow code must be **deterministic**: no random numbers, no current time, no calls to other services. Anything like that belongs in an activity.

## 2. Add the workflow

In the **Editor** tab, right-click the `MeridianDiagnostics/Engineering` folder, select **New File...** and name the file `DiagnosticsWorkflow.cs`. Paste the code below into it and save the file (`Ctrl+S`, or `Cmd+S` on a Mac):

```csharp,copy
using Dapr.Workflow;

public record DiagnosticsInput(string Id, string StarDate);
public record SubsystemReport(string Subsystem, string Status, int Reading);
public record DiagnosticsOutput(string StarDate, string Priority, string Summary, bool BridgeNotified);

public class DiagnosticsWorkflow : Workflow<DiagnosticsInput, DiagnosticsOutput>
{
    public override async Task<DiagnosticsOutput> RunAsync(WorkflowContext context, DiagnosticsInput input)
    {
        var logger = context.CreateReplaySafeLogger<DiagnosticsWorkflow>();
        logger.LogInformation("Starting diagnostics for stardate {StarDate}", input.StarDate);

        // Fan-out: check the three subsystems in parallel. Fan-in: wait for all three reports.
        string[] subsystems = ["WarpCore", "LifeSupport", "Shields"];
        var checks = subsystems
            .Select(s => context.CallActivityAsync<SubsystemReport>(nameof(DiagnoseSubsystemActivity), s))
            .ToList();
        var reports = await Task.WhenAll(checks);

        // Wait while the sensors settle. A durable timer survives a restart of the app.
        await context.CreateTimer(TimeSpan.FromSeconds(15));

        var priority = await context.CallActivityAsync<string>(nameof(PrioritizeDiagnosticsActivity), reports);

        var notified = false;
        if (priority == "Urgent")
        {
            notified = await context.CallActivityAsync<bool>(nameof(NotifyBridgeActivity), priority);
        }

        var summary = string.Join(", ", reports.Select(r => $"{r.Subsystem}={r.Status}"));
        logger.LogInformation("Diagnostics for stardate {StarDate} done: {Priority}", input.StarDate, priority);
        return new DiagnosticsOutput(input.StarDate, priority, summary, notified);
    }
}
```

- **The records.** `DiagnosticsInput` is what a diagnostics run starts with: an ID and a stardate. Each subsystem check returns a `SubsystemReport`, and the workflow returns a `DiagnosticsOutput`, which you'll read back with the status endpoint in lab 4.
- **The workflow class.** `DiagnosticsWorkflow` inherits from `Workflow<TInput, TOutput>`. Dapr calls `RunAsync` with the input and a `WorkflowContext`, and the workflow does everything through that context.
- **Replay-safe logging.** On a replay, `RunAsync` runs again from the start, so a normal logger would print `Starting diagnostics` again. The logger from `CreateReplaySafeLogger` only writes when the code runs for the first time, not on a replay.
- **Fan-out/fan-in.** `CallActivityAsync` schedules an activity and returns a task without waiting for it. The `Select` creates all three tasks first, so the three checks run in parallel, and `Task.WhenAll` waits for all three.
- **The durable timer.** `CreateTimer` is not `Task.Delay`: the sidecar keeps the timer in the workflow's history. If the app stops while the timer runs, the workflow continues once the app is back. You'll try that in lab 4.
- **Deterministic.** The workflow only uses its input and the results of its activities. The `if` depends on the priority, which is saved in the history, so a replay takes the same branch.

## 3. Add the activities

In the **Editor** tab, create a second file in the `MeridianDiagnostics/Engineering` folder, named `Activities.cs`. Paste the code below into it and save the file:

```csharp,copy
using Dapr.Workflow;

public class DiagnoseSubsystemActivity(ILogger<DiagnoseSubsystemActivity> logger)
    : WorkflowActivity<string, SubsystemReport>
{
    public override Task<SubsystemReport> RunAsync(WorkflowActivityContext context, string subsystem)
    {
        var reading = Random.Shared.Next(0, 100);
        var status = reading switch { < 30 => "Critical", < 60 => "Degraded", _ => "Nominal" };
        logger.LogInformation("{Subsystem} reads {Reading}: {Status}", subsystem, reading, status);
        return Task.FromResult(new SubsystemReport(subsystem, status, reading));
    }
}

public class PrioritizeDiagnosticsActivity : WorkflowActivity<SubsystemReport[], string>
{
    public override Task<string> RunAsync(WorkflowActivityContext context, SubsystemReport[] reports)
    {
        var critical = reports.Count(r => r.Status == "Critical");
        var degraded = reports.Count(r => r.Status == "Degraded");
        var priority = (critical, degraded) switch
        {
            ( > 0, _) => "Urgent",
            (0, > 0) => "Elevated",
            _ => "Routine"
        };
        return Task.FromResult(priority);
    }
}

public class NotifyBridgeActivity(ILogger<NotifyBridgeActivity> logger) : WorkflowActivity<string, bool>
{
    private static readonly string[] Officers =
        ["Captain Ilsa Varn", "Commander Anja Lindqvist", "Lieutenant Commander Dayo Okafor", "Ensign Mira Varga"];

    public override Task<bool> RunAsync(WorkflowActivityContext context, string priority)
    {
        var officer = Officers[Random.Shared.Next(Officers.Length)];
        logger.LogInformation("Notifying the bridge: {Officer}, priority {Priority}", officer, priority);
        return Task.FromResult(true);
    }
}
```

Each activity inherits from `WorkflowActivity<TInput, TOutput>` and does its work in `RunAsync`. Activities get their services, such as the `ILogger`, from the app's dependency injection, like any other class in an ASP.NET Core app.

- **`DiagnoseSubsystemActivity`** stands in for a real sensor: it picks a random reading from 0 to 99. Below 30 the subsystem is `Critical`, below 60 `Degraded`, otherwise `Nominal`.
- **`PrioritizeDiagnosticsActivity`** counts the critical and degraded reports. Any critical report makes the diagnostics `Urgent`, any degraded report `Elevated`, and otherwise they're `Routine`.
- **`NotifyBridgeActivity`** picks the officer who acknowledges the notification: Captain Ilsa Varn, Commander Anja Lindqvist, Lieutenant Commander Dayo Okafor or Ensign Mira Varga.

The activities use `Random`, which the workflow must not. That's fine in an activity: the sidecar saves each activity's result in the history, so a replay reuses the saved reading instead of running the activity again.

## 4. Register the workflow

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Aspire CLI** window to go to the `workflow-aspire` folder first:

```bash,run
cd /root/university-labs/workflow-aspire
```

Use the **Aspire CLI** window to replace the `Program.cs` that `dotnet new web` created with one that registers the workflow and adds two endpoints:

```bash,run
cat > MeridianDiagnostics/Engineering/Program.cs <<'EOF'
using Dapr.Workflow;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDaprWorkflow(options =>
{
    options.RegisterWorkflow<DiagnosticsWorkflow>();
    options.RegisterActivity<DiagnoseSubsystemActivity>();
    options.RegisterActivity<PrioritizeDiagnosticsActivity>();
    options.RegisterActivity<NotifyBridgeActivity>();
});

var app = builder.Build();

app.MapPost("/start", async (DiagnosticsInput input, DaprWorkflowClient client) =>
{
    var instanceId = await client.ScheduleNewWorkflowAsync(nameof(DiagnosticsWorkflow), input.Id, input);
    return Results.Ok(new { instanceId });
});

app.MapGet("/status/{id}", async (string id, DaprWorkflowClient client) =>
{
    var state = await client.GetWorkflowStateAsync(id);
    if (state is null || !state.Exists)
    {
        return Results.NotFound();
    }
    return Results.Ok(new
    {
        status = state.RuntimeStatus.ToString(),
        output = state.RuntimeStatus == WorkflowRuntimeStatus.Completed
            ? state.ReadOutputAs<DiagnosticsOutput>()
            : null
    });
});

app.Run();
EOF
```

The command writes the whole file, so running it again gives the same result. Open `MeridianDiagnostics/Engineering/Program.cs` in the **Editor** tab to see it.

- **`AddDaprWorkflow`** registers the workflow and the three activities with the workflow runtime, which runs inside the app. When the app starts, the runtime connects to the Dapr sidecar and waits for work: the sidecar tells it which workflow or activity to run next. The app gets its sidecar in the next lab, when the AppHost starts it.
- **`POST /start`** takes a JSON body such as `{"id":"jump-001","starDate":"47634.4"}` and schedules a new `DiagnosticsWorkflow` with the `id` as its instance ID. It returns `{"instanceId":"jump-001"}` straight away; the workflow runs in the background.
- **`GET /status/{id}`** reads the instance's state from the sidecar: its runtime status, such as `Running` or `Completed`, and the `DiagnosticsOutput` once it has completed. An unknown ID gives `404 Not Found`.

`DaprWorkflowClient` is the client that `AddDaprWorkflow` registers. It starts workflows and reads their state through the sidecar.

## 5. Build the project

Use the **Aspire CLI** window to build the `Engineering` project:

```bash,run
dotnet build MeridianDiagnostics/Engineering
```

The build ends with `Build succeeded`. If it reports errors instead, each error line starts with the file and the line, for example `Activities.cs(12,5)`. Compare that file with its code block above, save it, and build again. The most common cause is a file that was only partly pasted or not saved.

## 6. Check your work

The check below looks for the workflow in `DiagnosticsWorkflow.cs`, the three activities in `Activities.cs` and the workflow registration in `Program.cs`, and then builds the `Engineering` project. If something is missing or the build fails, the message names the section to redo. The next labs build on this code, so make sure the check passes before you continue.

<instruqt-task id="write_workflow"></instruqt-task>

---

You wrote the diagnostics workflow and its three activities, registered them in the `Engineering` app, and added the endpoints that start a diagnostics run and read its status.

## What's next?

In the next lab you'll describe the app in the AppHost, with the state store, the `engineering` project and its Dapr sidecar, and the Dev Dashboard, and start it all with `aspire run`.
