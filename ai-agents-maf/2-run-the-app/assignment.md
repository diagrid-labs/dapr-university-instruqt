In this challenge you'll inspect the PrDigest application, start the full stack with a single `aspire run`, then trigger a digest run and read the ranked pull-request digest the MAF agents produce. This is the happy path you will be running. It will take about 8 minutes.

This challenge uses two terminals:

- *Aspire Terminal* — for running the long-lived `aspire run` command.
- *Curl Terminal* —  for trigging the run of the workflow.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

All terminal paths start in `MAF/PrDigest`, which contains the `PrDigest.sln` solution.

## 1. Inspect the application

Open the **Editor** tab — it has the `PrDigest` solution loaded — and take a quick look at how the pieces fit together.

**AppHost dependencies** — `PrDigest.AppHost/PrDigest.AppHost.csproj` references the API service project and pulls in:

- `Aspire.Hosting.Valkey` — hosts the Valkey container used as the Dapr state store.
- `CommunityToolkit.Aspire.Hosting.Dapr` — lets the AppHost attach a Dapr sidecar to the API service.
- `Diagrid.Aspire.Hosting.Dashboard` — adds the Diagrid dashboard as an Aspire resource.

**AppHost.cs** — open `PrDigest.AppHost/AppHost.cs`. This is where Aspire wires everything together:

- `AddValkey(...)` starts the state store container, pinned to port `16379` and secured by a `cache-password` parameter.
- `AddProject<Projects.PrDigest_ApiService>("pr-digest")` registers the API service, waits for the state store, and passes `DATA_DIR`/`REPO` environment variables that tell the app which PR fixtures to read.
- `.WithDaprSidecar(...)` attaches a Dapr sidecar to the API service with `AppId = "pr-digest"`, loading Dapr components from the `resources` folder.
- `CRASH_AFTER_AGENT_CALLS` is an environment variable you'll use later in the track to force a crash mid-workflow and prove durable execution.

**ApiService dependencies** — `PrDigest.ApiService/PrDigest.ApiService.csproj` adds:

- `Dapr.Workflow` — the Dapr Workflow authoring SDK.
- `Diagrid.AI.Microsoft.AgentFramework` — bridges Microsoft Agent Framework (MAF) agents to Dapr, so workflow code can call agents as durable activities.
- `Microsoft.Extensions.AI` — the abstractions MAF agents build on.

**Program.cs** — open `PrDigest.ApiService/Program.cs`. `AddDaprAgents(...)` registers the workflow and its activities, then `.WithAgent(...)` registers the `PrAnalyzer` and `Summarize` agents against the `conversation-prdigest` Dapr component — this is how the agents reach OpenAI without the application ever holding an API key or a model client. Further down, `/start`, `/status/{instanceId}`, `/pause/{instanceId}`, `/resume/{instanceId}`, and `/terminate/{instanceId}` are the endpoints you'll use to drive the workflow through `DaprWorkflowClient`.

**PrDigestWorkflow.cs** — open `PrDigest.ApiService/Workflows/PrDigestWorkflow.cs`, the orchestration itself:

- It lists the open pull requests, then fans out one checkpointed agent call per PR — each call analyzes a PR with the `PrAnalyzer` agent and durably records that the call happened.
- A single failed agent call doesn't fail the whole run — that PR is just marked `Degraded: true`.
- Once every PR is analyzed, the results are deterministically ranked by risk score, and the `Summarize` agent writes a short headline for the digest.
- The ranked digest is written to disk as `pr-digest.md`.

## 2. Run the application

Start the Aspire solution using the **Aspire Terminal**:

```shell,run,copy
aspire run
```

Aspire starts the API service, its Dapr sidecar, and a Valkey state store, then prints a dashboard URL.

Switch to the *Aspire* tab and wait until all resources show **Running**:

- `statestore` — the Valkey container that durably stores workflow state.
- `pr-digest` — the API service hosting the workflow and the MAF agents.
- `pr-digest-dapr-sidecar` — the Dapr sidecar.

> [!NOTE]
> Don't click the resource URLs inside the Aspire dashboard — they open outside the sandbox and won't work. Navigate using the dashboard's own views instead.

> [!IMPORTANT]
> Leave `aspire run` running for the rest of this challenge.

## 3. Start a digest run

The API service exposes a `/start` endpoint on the fixed port `5090`. In the *Curl Terminal*, schedule a workflow over 7 `dapr/dapr` pull requests:

```curl,run
curl -X POST "http://localhost:5090/start" -H "Content-Type: application/json" -d '{
  "id": "run-1",
  "repo": "dapr/dapr",
  "maxPrs": 7
}'
```

The response echoes the workflow instance id:

```json,nocopy
{ "instanceId": "run-1" }
```

Behind the scenes the workflow fans out one `PrAnalyzer` agent call per pull request — these are the LLM round-trips — then ranks the results and asks the `Summarize` agent for a headline.

## 4. Poll until the workflow completes

The agent calls take a little time. Poll the `/status/{instanceId}` endpoint until the run reports completed. In the *Curl Terminal*:

```bash,run
endpoint="http://localhost:5090"
until curl -s "$endpoint/status/run-1" | grep -qi '"completed"'; do
  echo "Workflow running..."
  sleep 2
done
echo "Workflow completed! ✅"
```

> [!NOTE]
> You can use the **Aspire** tab to inspect the application logs — you'll see a `🤖 Analyzing PR #...` line for each pull request as its agent call executes.

## 5. Read the digest

The workflow writes a ranked Markdown digest to an output directory (`/root/digest-out`). Use the **Editor** tab to navigate to this folder and inspect the content of the generated output.

The digest ranks the pull requests by a computed **risk score** and includes, for each one:

- Rank, PR number, and title
- Risk score and flags (e.g. `many-files`, `large-diff`, `no-tests`, `no-linked-issue`)
- A summary and risk rationale — written by the `PrAnalyzer` agent
- The linked issue, if any

At the top is the headline written by the `Summarize` agent. The exact pull requests and scores depend on the bundled data snapshot.

> [!IMPORTANT]
> Click the *Check* button to verify the digest was generated.

---

You've run an agentic workflow end-to-end: each row in that digest cost a real LLM call. Next you'll crash the app mid-run and prove those calls are **not** repeated on resume.
