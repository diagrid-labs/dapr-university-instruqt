In this challenge you'll inspect the PrDigest application. You'll look at the AppHost configuration, MAF agent configuration, and workflow code. And you'll do a `dotnet build` to ensure the application compiles correctly before running it in the next challenge. The challenge will take about 8 minutes.

## 1. Build the application

Build the Aspire solution using the **Aspire Terminal**:

```shell,run,copy
dotnet build
```

While the application is restoring dependencies and building, let's take a look at the structure and code of the application.

## 2. Inspect the application

Use the **Editor** tab, it has the `PrDigest` solution loaded, and take a look at how the pieces fit together.

You'll see the typical Aspire projects: ApiService, AppHost and ServiceDefaults.
You'll also see a `data` folder that has json files in a dapr/dapr subfolder. These are serialized GitHub pull requests from the `dapr/dapr` repository that the application will analyze. So you're not connecting to the live GitHub repo which would require authentication.

### 2.1 PrDigest.AppHost

The `PrDigest.AppHost/PrDigest.AppHost.csproj` project has the following dependencies:

- `Aspire.Hosting.Valkey` — hosts the Valkey container used as the Dapr state store for workflow state.
- `CommunityToolkit.Aspire.Hosting.Dapr` — lets the AppHost attach a Dapr sidecar to the API service.

Open `PrDigest.AppHost/AppHost.cs`. This is where Aspire wires everything together:

- `AddValkey(...)` starts the state store container, pinned to port `16379` and secured by a `cache-password` parameter.
- `AddProject<Projects.PrDigest_ApiService>("pr-digest")` registers the API service, waits for the state store, and passes `DATA_DIR`/`REPO` environment variables that tell the app which PR fixtures to read.
- `.WithDaprSidecar(...)` attaches a Dapr sidecar to the API service with `AppId = "pr-digest"`, loading Dapr components from the `resources` folder.
- `CRASH_AFTER_AGENT_CALLS` is an environment variable you'll use later in the track to force a crash mid-workflow and prove durable execution.

```csharp,nocopy
var builder = DistributedApplication.CreateBuilder(args);

var statePassword = builder.AddParameter("cache-password", "state-store-123", secret: true);
var stateStore = builder
    .AddValkey("statestore", 16379, statePassword)
    .WithContainerName("pr-digest-state")
    .WithDataVolume("pr-digest-state-data");

var dataDir = Path.GetFullPath(Path.Combine(builder.AppHostDirectory, "..", "data"));

builder.AddProject<Projects.PrDigest_ApiService>("pr-digest")
    .WithReference(stateStore)
    .WaitFor(stateStore)
    .WithEnvironment("DATA_DIR", dataDir)
    .WithEnvironment("REPO", "dapr/dapr")
    .WithEnvironment("CRASH_AFTER_AGENT_CALLS",
        Environment.GetEnvironmentVariable("CRASH_AFTER_AGENT_CALLS") ?? "0")
    .WithEndpoint("http", endpoint => endpoint.Port = 5090)
    .WithDaprSidecar(new DaprSidecarOptions
    {
        AppId = "pr-digest",
        ResourcesPaths = ["resources"]
    });

builder.Build().Run();
```

### 2.2 PrDigest.ApiService

The `PrDigest.ApiService/PrDigest.ApiService.csproj` has the following dependencies:

- `Dapr.Workflow` — the Dapr Workflow authoring SDK.
- `Diagrid.AI.Microsoft.AgentFramework` — bridges Microsoft Agent Framework (MAF) agents to Dapr, so workflow code can call agents as durable activities.
- `Microsoft.Extensions.AI` — the abstractions MAF agents build on.

#### Program.cs

Open `PrDigest.ApiService/Program.cs`; this contains the startup code and endpoints for the ApiService.

`AddDaprAgents(...)` registers the workflow and its activities, then `.WithAgent(...)` registers the `PrAnalyzer` and `Summarize` agents against the `conversation-prdigest` Dapr component — this is how the agents reach OpenAI without the application ever holding an API key or a model client. Further down, `/start`, `/status/{instanceId}`, `/pause/{instanceId}`, `/resume/{instanceId}`, and `/terminate/{instanceId}` are the endpoints to manage the workflow.

```csharp,nocopy
builder.Services.AddDaprAgents(
        opt => opt.AddContext(() => PrDigestJsonContext.Default),
        opt =>
        {
            opt.RegisterWorkflow<PrDigestWorkflow>();
            opt.RegisterActivity<ListOpenPullRequestsActivity>();
            opt.RegisterActivity<FetchPullRequestDetailActivity>();
            opt.RegisterActivity<RecordAgentCallActivity>();
            opt.RegisterActivity<WriteDigestActivity>();
        })
    .WithAgent(
        agentName: AgentNames.PrAnalyzer,
        conversationComponentName: "conversation-prdigest",
        instructions: AgentInstructions.PrAnalyzer,
        serviceLifetime: ServiceLifetime.Singleton)
    .WithAgent(
        agentName: AgentNames.Summarize,
        conversationComponentName: "conversation-prdigest",
        instructions: AgentInstructions.Summarize,
        serviceLifetime: ServiceLifetime.Singleton);

var app = builder.Build();

app.MapPost("/start", async (
    [FromServices] DaprWorkflowClient workflowClient,
    [FromBody] PrDigestInput input) =>
{
    var instanceId = await workflowClient.ScheduleNewWorkflowAsync(
        name: nameof(PrDigestWorkflow),
        instanceId: input.Id,
        input: input);
    return Results.Ok(new { instanceId });
});
```

#### PrDigestWorkflow.cs

Open `PrDigest.ApiService/Workflows/PrDigestWorkflow.cs`; this contains the orchestration of activities and MAF agents:

- It lists the open pull requests, then fans out one checkpointed agent call per PR — each call analyzes a PR with the `PrAnalyzer` agent and durably records that the call happened.
- A single failed agent call doesn't fail the whole run — that PR is just marked `Degraded: true`.
- Once every PR is analyzed, the results are deterministically ranked by risk score, and the `Summarize` agent writes a short headline for the digest.
- The ranked digest is written to disk as `pr-digest.md`.

```csharp,nocopy
public override async Task<PrDigestOutput> RunAsync(WorkflowContext context, PrDigestInput input)
    {
        var logger = context.CreateReplaySafeLogger<PrDigestWorkflow>();
        LogStart(logger, context.InstanceId, input.Repo, input.MaxPrs);

        var prs = await context.CallActivityAsync<IReadOnlyList<PrListItem>>(
            nameof(ListOpenPullRequestsActivity), input.MaxPrs);

        var analyzer = context.GetAgent(AgentNames.PrAnalyzer);

        // Durable fan-out: one checkpointed agent call per PR.
        var analysisTasks = prs.Select(pr => AnalyzeOneAsync(context, analyzer, pr, logger)).ToList();
        var results = await Task.WhenAll(analysisTasks);

        // Deterministic fan-in.
        var ranked = DigestRanker.Rank(results);

        var summarizer = context.GetAgent(AgentNames.Summarize);
        var header = await context.RunAgentAndDeserializeAsync<DigestHeader>(
            agent: summarizer,
            logger: logger,
            message: BuildHeadlinePrompt(ranked));
        var headline = header?.Headline ?? "Digest summary unavailable.";

        var path = await context.CallActivityAsync<string>(
            nameof(WriteDigestActivity), new WriteDigestInput(input.Repo, headline, ranked));

        LogDone(logger, context.InstanceId, results.Length, path);
        return new PrDigestOutput(input.Repo, results.Length, path, headline);
    }
```

The `AnalyzeOneAsync` method fetches the PR data with `FetchPullRequestDetailActivity`, analyzes it with a MAF agent, and logs the result with `RecordAgentCallActivity`:

```csharp,nocopy
private static async Task<PrResult> AnalyzeOneAsync(
        WorkflowContext context, IDaprAIAgent analyzer, PrListItem pr, ILogger logger)
    {
        var risk = RiskModel.Score(pr.Metrics);

        // Fetch the PR detail deterministically (local file I/O)
        var detail = await context.CallActivityAsync<PrToolResult>(
            nameof(FetchPullRequestDetailActivity), pr.Number);

        // A single faulted agent call must not fail the whole fan-out, so degrade this one
        // PR (Degraded: true) instead of letting the exception propagate through
        // Task.WhenAll. Deterministic metrics and risk are still reported.
        PrAnalysis? analysis;
        try
        {
            // Replay-safe: this prints once per PR on first execution and stays silent when
            // the workflow replays after a crash — so on resume only the not-yet-analyzed
            // PRs log, visibly demonstrating that completed agent calls are not repeated.
            LogAnalyzing(logger, pr.Number);
            analysis = await context.RunAgentAndDeserializeAsync<PrAnalysis>(
                agent: analyzer,
                logger: logger,
                message: BuildAnalysisPrompt(detail));
        }
        catch (Exception ex)
        {
            LogAnalysisDegraded(logger, pr.Number, ex.Message);
            analysis = null;
        }

        // Durably record that this PR's agent call ran. Checkpointed like any activity, so on
        // resume it replays from history (no duplicate ledger line) and the deterministic
        // crash gate inside it fires exactly once.
        await context.CallActivityAsync<bool>(
            nameof(RecordAgentCallActivity), new AgentCallRecord(pr.Number, pr.Title));

        return analysis is null
            ? new PrResult(pr.Number, pr.Title, pr.Metrics, risk, Analysis: null, Degraded: true)
            : new PrResult(pr.Number, pr.Title, pr.Metrics, risk, analysis, Degraded: false);
    }
```

#### RecordAgentCallActivity.cs

Open `PrDigest.ApiService/Activities/RecordAgentCallActivity.cs`; this is the logging activity that is called right after calling the `PrAnalyzer` agent. This also contains code to handle the deterministic crash of the application.

```csharp,nocopy
public sealed partial class RecordAgentCallActivity(ILogger<RecordAgentCallActivity> logger)
    : WorkflowActivity<AgentCallRecord, bool>
{
    // Counts agent calls executed in THIS process. Resets to zero on restart, which is
    // exactly what we want: after a crash, completed calls replay from history without
    // re-entering this activity, so only genuinely new calls are counted.
    private static int _executedCalls;

    public override Task<bool> RunAsync(WorkflowActivityContext context, AgentCallRecord record)
    {
        var outputDir = DemoPaths.OutputDirectory();
        var count = Interlocked.Increment(ref _executedCalls);

        var threshold = ParseThreshold(Environment.GetEnvironmentVariable("CRASH_AFTER_AGENT_CALLS"));
        var gate = new CrashGate(threshold, Path.Combine(outputDir, "agent-calls.crash-marker"));
        if (gate.ShouldCrash(count))
        {
            LogCrashing(logger, count);
            // Ungraceful, immediate termination — simulates a real process crash so we can
            // prove the workflow resumes from durable Valkey state without redoing work.
            Environment.FailFast($"PrDigest durability demo: simulated crash after {count} agent call(s).");
        }

        new AgentCallLedger(outputDir).Append(record.Number, record.Title, DateTime.UtcNow);
        LogRecorded(logger, record.Number, count);
        return Task.FromResult(true);
    }

    private static int ParseThreshold(string? raw) =>
        int.TryParse(raw, out var n) && n > 0 ? n : 0;

    [LoggerMessage(LogLevel.Warning,
        "💥 CRASH GATE TRIPPED after {Count} agent call(s) — killing the process to simulate a crash.")]
    static partial void LogCrashing(ILogger logger, int count);

    [LoggerMessage(LogLevel.Information,
        "📒 Recorded agent call for PR #{Number} (call #{Count} in this process).")]
    static partial void LogRecorded(ILogger logger, int number, int count);
}
```

---

You've inspected the agentic workflow end-to-end. In the next challenge you'll start the application and crash it mid-run and prove the LLM calls are **not** repeated on resume.
