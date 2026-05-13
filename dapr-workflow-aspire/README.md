# Manual Instructions: USS Enterprise Diagnostics (Aspire + Dapr Workflow)

Step-by-step instructions for building an Aspire workflow application that diagnoses 3 USS Enterprise subsystems in parallel, prioritizes the results, and notifies the bridge if the priority is urgent. All activities use randomly generated mock data.

The project name throughout is **`EnterpriseDiagnostics`** — change it consistently if you'd like a different name.

---

# Module 2 — Project Creation

Open a terminal in the directory where you want the solution folder created, then run the commands below.

## 2.1 Scaffold the Aspire solution

Start by running the following `aspire new` command to scaffold the `aspire-starter` template solution:

```shell,run
aspire new aspire-starter -n EnterpriseDiagnostics -o EnterpriseDiagnostics --non-interactive --test-framework none
```

> The `--non-interactive` and `--test-framework none` flags are required, otherwise the CLI blocks waiting for user input.

Expected output:

```text,nocopy
Searching for available project template versions...
🧊 Getting templates...
📦 Using project templates version: 13.3.0
🚀 Creating new Aspire project...
🔐 Trusting certificates...
⚠️ Developer certificates may not be fully trusted (trust exit code was: PartiallyFailedToTrustTheCertificate).
✅ Project created successfully in /root/dapr-workflow-aspire/EnterpriseDiagnostics.
Detecting agent environments...
✅ Installed aspire skill (.agents/skills/aspire).
✅ Installed aspire skill (~/.agents/skills/aspire).
✅ Installed aspireify skill (.agents/skills/aspireify).
✅ Installed aspireify skill (~/.agents/skills/aspireify).
✅ Agent environment configuration complete.
```

Refresh the Editor window, that should show the EnterpriseDiagnostics solution now.

## 2.2 About the generated Web project

The starter template also generates an `EnterpriseDiagnostics.Web` Blazor project. We won't use it in this walkthrough — you can ignore it and leave it in place.

Move into the solution folder for the remaining commands:

```shell,run,copy
cd EnterpriseDiagnostics
```

## 2.3 Fix the AppHost launch URLs (HTTP + fixed ports)

Open `EnterpriseDiagnostics.AppHost/Properties/launchSettings.json`.

1. Remove the `https` profile completely.
2. Update the`http` profile as follows:

```json,copy
    "http": {
    "commandName": "Project",
    "dotnetRunMessages": true,
    "launchBrowser": true,
    "applicationUrl": "http://0.0.0.0:17000",
    "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "DOTNET_ENVIRONMENT": "Development",
        "ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL": "http://0.0.0.0:17001",
        "ASPIRE_RESOURCE_SERVICE_ENDPOINT_URL": "http://0.0.0.0:17003",
        "DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS": true,
        "ASPIRE_ALLOW_UNSECURED_TRANSPORT": true
        }
    },
```

> [!IMPORTANT]
> Use `0.0.0.0` instead of `localhost` and ensure the port numbers match exactly with the above profile, otherwise the Aspire dashboard can't be access in the learning environment. Also ensure that the `DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS` and `ASPIRE_ALLOW_UNSECURED_TRANSPORT` variables are set to `true`.

## 2.4 Add the NuGet packages

Now let's install some depedencies the solution requires. You'll build a Dapr Workflow solution so this needs: `Dapr.Workflow`, `Dapr.Workflow.Versioning` and `CommunityToolkit.Aspire.Hosting.Dapr`.

Workflows require a state store and for that Valkey (Redis compatible) will be used: `Aspire.Hosting.Valkey`.

Finally, an Aspire integration is added to use the Diagrid Dev Dashboard. An essential tool for local Dapr workflow inspection: `Diagrid.Aspire.Hosting.Dashboard`

Run from the **solution root** (`EnterpriseDiagnostics/`) to install all the required packages to the correct project:

```shell,run,copy
dotnet add EnterpriseDiagnostics.ApiService/EnterpriseDiagnostics.ApiService.csproj package Dapr.Workflow --version 1.17.9
dotnet add EnterpriseDiagnostics.ApiService/EnterpriseDiagnostics.ApiService.csproj package Dapr.Workflow.Versioning --version 1.17.9
dotnet add EnterpriseDiagnostics.AppHost/EnterpriseDiagnostics.AppHost.csproj package CommunityToolkit.Aspire.Hosting.Dapr --version 13.0.0
dotnet add EnterpriseDiagnostics.AppHost/EnterpriseDiagnostics.AppHost.csproj package Aspire.Hosting.Valkey --version 13.3.0
dotnet add EnterpriseDiagnostics.AppHost/EnterpriseDiagnostics.AppHost.csproj package Diagrid.Aspire.Hosting.Dashboard
```

The AppHost project  should have these packages:

```text,nocopy
<PackageReference Include="Aspire.Hosting.Valkey" Version="13.3.0" />
<PackageReference Include="CommunityToolkit.Aspire.Hosting.Dapr" Version="13.0.0" />
<PackageReference Include="Diagrid.Aspire.Hosting.Dashboard" Version="0.0.1" />
```

The ApiService project  should have these packages:

```text,nocopy
<PackageReference Include="Dapr.Workflow" Version="1.17.9" />
<PackageReference Include="Dapr.Workflow.Versioning" Version="1.17.9" />
<PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="10.0.7" />
```

Run a `dotnet build` to verify to solution builds correctly.

```shell,run,copy
dotnet build
```

Then run aspire and check if the *Aspire Dashboard* shows

```shell,run,copy
aspire run
```

---

# Module 3 — Workflow & Activity Definition

Now that the dependencies are available, the workflow and activity code can be added. All workflow related files will live in the `EnterpriseDiagnostics.ApiService/` project. Create the following folders using the *Terminal* ensuring the path is currently `EnterpriseDiagnostics/`:

```shell,run
mkdir EnterpriseDiagnostics.ApiService/Models
mkdir EnterpriseDiagnostics.ApiService/Workflows
mkdir EnterpriseDiagnostics.ApiService/Activities
```

Refresh the *Editor* window afterwards so you see the new folders.

## 3.1 Models — `Models/Models.cs`

Create the models first, they are all `record` type and placed in the same `Models.cs` file. There are input and output records for the workflow, the subsystem diagnostics the prioritization, and the bridge notification activities.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Models/Models.cs
```

Then copy the code:

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

## 3.2 Workflow — `Workflows/EnterpriseDiagnosticsWorkflow.cs`

Now create the workflow, it will fan-out/fan-in over 3 subsystems to run diagnostics, then prioritize, then conditionally notify the bridge.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Workflows/EnterpriseDiagnosticsWorkflow.cs
```

Then copy the code:

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

        var diagnosticsTasks = Subsystems.Select(name =>
            context.CallActivityAsync<SubsystemDiagnosticsOutput>(
                nameof(DiagnoseSubsystemActivity),
                new SubsystemDiagnosticsInput(name)));

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

## 3.3 Activity — `Activities/DiagnoseSubsystemActivity.cs`

Now create the DiagnoseSubsystemActivity, it returns randomly-generated mock telemetry for a single subsystem.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Activities/DiagnoseSubsystemActivity.cs
```

Then copy the code:

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

## 3.4 Activity — `Activities/PrioritizeDiagnosticsActivity.cs`

Create the PrioritizeDiagnosticsActivity which aggregates the three subsystem reports into a single prioritized report.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Activities/PrioritizeDiagnosticsActivity.cs
```

Then copy the code:

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

## 3.5 Activity — `Activities/NotifyBridgeActivity.cs`

Create the final activity, NotifyBridgeActivity, that mock-notifies the bridge with a randomly chosen acknowledging officer.

First create the file:

```shell,run,copy
touch EnterpriseDiagnostics.ApiService/Activities/NotifyBridgeActivity.cs
```

Then copy the code:

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

## 3.6 Update `EnterpriseDiagnostics.ApiService/Program.cs`

Replace the file contents with:

```csharp
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

> Workflow types are auto-registered by `AddDaprWorkflowVersioning()` — only activities need explicit `RegisterActivity<T>()` calls.

## 3.7 Verify

From the solution root:

```shell
dotnet build EnterpriseDiagnostics.sln
```

Fix any errors before continuing.

---

# Module 4 — AppHost Definition & Resources

There are two files required under the AppHost project:

1. A Dapr state store component that is used by Dapr Workflow
2. A Dapr state store component that is used by the Diagrid Dev Dashboard

Both files point to the same state store (Valkey) but require a different value for `redisHost` due to networking.

Ensure that the *Terminal* path currently in `EnterpriseDiagnostics/`.

## 4.1 `Resources/dapr/workflow-state.yaml`

Let's create the component file used by Dapr to store workflow state. This will be the location of the file: `Resources/dapr/workflow-state.yaml`.

1. Create the folder using the *Terminal*:

```shell,run,copy
mkdir EnterpriseDiagnostics.AppHost/Resources/dapr
```

2. Create the empty component file using the *Terminal*:

```shell,run,copy
touch EnterpriseDiagnostics.AppHost/Resources/dapr/diagrid-dashboard-components/diagrid-dashboard-state.yaml
```

3. Refresh the *Editor* window to see the new file.

4. Update the content of the empty file using the *Editor* window:

```yaml,copy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: workflow-state
spec:
  type: state.redis
  version: v1
  metadata:
    - name: redisHost
      value: "localhost:16379"
    - name: redisPassword
      value: "state-store-123"
    - name: actorStateStore
      value: true
```

## 4.2 `Resources/dapr/diagrid-dashboard-components/diagrid-dashboard-state.yaml`

The Diagrid Dev Dashboard requires a connection to the statestore that is based on a Dapr component file. The default location for the Diagrid Dev Dashboard Aspire integration is `Resources/dapr/diagrid-dashboard-components` in the AppHost project.

1. Create the folder using the *Terminal*:

```shell,run,copy
mkdir EnterpriseDiagnostics.AppHost/Resources/dapr/diagrid-dashboard-components
```

2. Create the empty component file using the *Terminal*:

```shell,run,copy
touch EnterpriseDiagnostics.AppHost/Resources/dapr/diagrid-dashboard-components/diagrid-dashboard-state.yaml
```

3. Refresh the *Editor* window to see the new file.

4. Copy the following component spec in the empty file using the *Editor* window:

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: diagrid-dashboard-store
scopes:
  - diagrid-dashboard
spec:
  type: state.redis
  version: v1
  metadata:
    - name: redisHost
      value: "host.docker.internal:16379"
    - name: redisPassword
      value: "state-store-123"
    - name: actorStateStore
      value: true
```

## 4.3 Update `EnterpriseDiagnostics.AppHost.csproj`

The two Dapr component files in the Resources folder need to be available when the Aspire solution runs.

Add a `Content` item group so the component files are copied to the output directory. Use the *Editor* window to add the item group to the `EnterpriseDiagnostics.AppHost.csproj` file:

```xml,copy
  <ItemGroup>
    <Content Include="Resources\**\*.*">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
      <Link>Resources\%(RecursiveDir)%(Filename)%(Extension)</Link>
    </Content>
  </ItemGroup>
```

## 4.4 Replace `AppHost.cs`

```csharp
using System.Reflection;
using CommunityToolkit.Aspire.Hosting.Dapr;
using Diagrid.Aspire.Hosting.Dashboard;

var builder = DistributedApplication.CreateBuilder(args);

builder.AddDapr();

string executingPath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location)
    ?? throw new("Where am I?");

var cachePassword = builder.AddParameter("cache-password", "state-store-123", secret: true);
var cache = builder
    .AddValkey("cache", 16379, cachePassword)
    .WithContainerName("workflow-state")
    .WithDataVolume("workflow-state-data");

var apiService = builder
    .AddProject<Projects.EnterpriseDiagnostics_ApiService>("apiservice")
    .WithHttpsEndpoint(port: 7337, name: "https")
    .WithHttpEndpoint(port: 5411, name: "http")
    .WithDaprSidecar(new DaprSidecarOptions
    {
        LogLevel = "debug",
        ResourcesPaths =
        [
            Path.Join(executingPath, "Resources", "dapr"),
        ],
    });

apiService.WaitFor(cache);
builder.AddDiagridDashboard();

builder.Build().Run();

```

> The explicit `WithHttpsEndpoint` / `WithHttpEndpoint` calls pin the apiservice to fixed ports so the URL stays stable across runs (same idea as §2.3 for the Aspire dashboard itself).

## 4.5 Verify

From the solution root:

```shell
dotnet build EnterpriseDiagnostics.sln
```

---

# Module 5 — Run Application

## 5.1 Start Aspire

From the solution root:

```shell
aspire run
```

The Aspire dashboard opens automatically in your browser. Wait until **`apiservice`**, **`cache`**, and **`diagrid-dashboard`** all show as Running.

## 5.2 Find the ApiService URL

Because §3.4 pins the apiservice to fixed ports, its HTTPS endpoint is always `https://localhost:7337`. Use this URL in the curl commands below as `<API_URL>` (you can also confirm it in the Aspire dashboard under the **`apiservice`** resource).

## 5.3 Start a workflow with curl

```shell
curl -k -X POST <API_URL>/start ^
  -H "Content-Type: application/json" ^
  -d "{\"id\":\"mission-001\",\"starDate\":\"41153.7\"}"
```

(PowerShell users: replace `^` line continuations with backticks `` ` ``, or put it all on one line.)

The response returns the `instanceId`, e.g.:

```json
{ "instanceId": "mission-001" }
```

## 5.4 Check the workflow status

```shell
curl -k <API_URL>/status/mission-001
```

The response contains the workflow `state` and the deserialized `output` with `StarDate`, `Priority`, `Summary`, and `BridgeNotified` fields.

## 5.5 Open the Diagrid Dev Dashboard

In the Aspire dashboard, find the **`diagrid-dashboard`** resource and click its HTTP endpoint (port 8080). In the dashboard you can:

- Browse all workflow instances backed by the `workflow-state` component.
- See the timeline of activity executions (the three parallel `DiagnoseSubsystemActivity` calls, then `PrioritizeDiagnosticsActivity`, and conditionally `NotifyBridgeActivity`).
- Inspect inputs and outputs for each step.

Run the workflow several times with different `id` values — because the activities use random data, you'll see runs that escalate to **Urgent** (and trigger `NotifyBridgeActivity`) and others that resolve to **Normal** or **Warning**.
