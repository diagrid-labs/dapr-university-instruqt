# dapr-workflow-aspire drift tests — design

## Goal

Add Robot Framework drift tests for the `dapr-workflow-aspire` track under the
existing harness (`tools/track-tester/`). Because this track is **build-it-live**
(the learner scaffolds and pastes every file from the assignments — there is no
upstream repo to clone), the suite reconstructs the app by extracting the exact
`,copy` / `,run` fenced blocks from the assignments, builds and runs it, and
asserts the workflow completes. This catches drift in the tooling the assignment
depends on: the `aspire-starter` template, the pinned NuGet versions, .NET 10,
the Aspire CLI, Dapr, and the `dapr_redis` state store.

## What makes this track different from dapr-workflow / dapr-101 (verified)

- **Code source = the assignments themselves.** Every C#/JSON/YAML/XML file is
  pasted from a `,copy` fenced block; every command is a `shell,run` /
  `shell,run,copy` block. Nothing is cloned from `dapr/quickstarts`. The drift
  signal is therefore *tooling* drift (template, package versions, SDK, CLI),
  not upstream-code drift.
- **Challenges are cumulative**, not independent. ch3's build needs ch2's
  scaffold; ch4 needs ch3's code; ch5 runs the whole thing. This is one
  continuous working directory, unlike dapr-workflow's per-challenge quickstart
  folders.
- **Single language (.NET only)** — no dotnet/java/python tag matrix.
- **Aspire orchestrates the Dapr sidecar** (`builder.AddDapr()` +
  `WithDaprSidecar` in `AppHost.cs`), rather than `dapr run -f .`. The ApiService
  is pinned to `http://localhost:5411` via `WithHttpEndpoint(port: 5411)`. The
  workflow state store (`Resources/dapr/workflow-state.yaml`) points at
  `localhost:6379` — the `dapr_redis` container started by `dapr init`.
- **ch1 (introduction) is pure reading** — no runnable commands, no suite.
- **The diagrid-dashboard step in ch5 is read-only visualization** — it asserts
  nothing about the workflow, so it is executed by neither the suite nor the
  setup script (skipped by design).
- **Fence tag is `shell`, not `bash`.** The current
  `docsync/check_doc_sync.py` treats only `bash,run` as runnable, so it does not
  recognize this track's blocks.

## Key facts (from the assignments)

- **Pinned versions** (drift-sensitive): `Dapr.Workflow 1.18.4`,
  `Dapr.Workflow.Versioning 1.18.4`, `CommunityToolkit.Aspire.Hosting.Dapr
  13.0.0`; `dotnet new aspire-starter` (the assignment explicitly says *not* to
  upgrade Aspire).
- **Scaffold:** `dotnet new aspire-starter -n EnterpriseDiagnostics -o
  EnterpriseDiagnostics`, then all remaining commands run inside
  `EnterpriseDiagnostics/`.
- **Runtime prerequisites:** .NET 10 SDK, Aspire CLI, Dapr CLI + `dapr init`
  (provides the `dapr_redis` container the workflow state store points at),
  Docker daemon (for the Dapr containers).
- **Workflow shape:** fan-out to three subsystem activities → prioritize →
  conditionally notify the bridge. Activity results are randomized
  (`Random.Shared`), so `Priority`/`Summary` vary run to run. The stable,
  assertable facts are: the workflow reaches completion, and the output echoes
  the input `starDate` (`41153.7`) and carries a `Priority` field.
- **Interaction:** `curl -X POST http://localhost:5411/start` with
  `{"id":"mission-001","starDate":"41153.7"}` → poll `GET
  http://localhost:5411/status/mission-001`.

## Architecture — extract, apply, run

A single cumulative suite (`dapr-workflow-aspire/tests/challenge.robot`) drives
four ordered checkpoint test cases in one working directory
(`${TEMPDIR}/EnterpriseDiagnostics-track`). The cases must run in order and share
state; each applies the next assignment's steps on top of the prior state:

| Test case | Applies (from assignment.md) | Asserts |
|---|---|---|
| Ch2 Scaffold & Build | ch2 `shell,run` blocks (scaffold, `cd`, NuGet adds) + write `launchSettings.json` | `dotnet build` rc 0; ApiService `.csproj` carries the pinned Dapr package versions |
| Ch3 Workflow Build | ch3 `mkdir`/`touch` blocks + write the 6 code files (3 activities, models, workflow, `Program.cs`) | `dotnet build` rc 0 |
| Ch4 AppHost Build | ch4 write 2 component YAMLs, edit `.csproj`, replace `AppHost.cs` | `dotnet build` rc 0 |
| Ch5 Run & Assert | `aspire run` (background) → `curl POST /start` → poll `GET /status/mission-001` | workflow reaches completion; output echoes `starDate 41153.7` and carries a `Priority` |

### Extraction

A Python library `tools/track-tester/libraries/assignment_blocks.py`, imported by
the suite as a `Library`, does the reconstruction:

- **Parse** fenced blocks from an `assignment.md`, capturing each block's info
  string (e.g. `shell,run`, `csharp,copy`, `json,copy`, `yaml,copy`, `xml,copy`,
  `text,nocopy`) and body.
- **Run-blocks** (`shell,run` / `shell,run,copy`): execute in document order.
  The harness tracks the `cd EnterpriseDiagnostics` (and any other `cd`) so
  subsequent commands run in the right cwd. `,nocopy` blocks are display-only and
  are never executed.
- **File-blocks** (`,copy` blocks that are `csharp`/`json`/`yaml`/`xml`): write
  the body to a destination path resolved from a **per-challenge manifest**.

### Block → file manifest

The destination for each file-block is described in prose, not machine-readable,
so a manifest in `variables/dapr_workflow_aspire.py` maps blocks to targets.
Entries are keyed on a **unique content anchor** (a substring the block body must
contain) rather than an ordinal, so the mapping survives block reordering. For
example:

- body contains `class DiagnoseSubsystemActivity` →
  `EnterpriseDiagnostics.ApiService/Activities/DiagnoseSubsystemActivity.cs`
- body contains `namespace EnterpriseDiagnostics.Models` →
  `EnterpriseDiagnostics.ApiService/Models/Models.cs`
- body contains `"$schema": "https://json.schemastore.org/launchsettings.json"`
  → `EnterpriseDiagnostics.AppHost/Properties/launchSettings.json`
- body contains `name: workflow-state` →
  `EnterpriseDiagnostics.AppHost/Resources/dapr/workflow-state.yaml`

The `.csproj` `<Content>` item-group edit (ch4) and the NuGet `dotnet add`
commands (ch2) are *insertions/commands*, not whole-file replacements, and are
handled as run-blocks or a targeted insert keyword — resolved in implementation.

## Components (new files)

- **Suite** (new): `dapr-workflow-aspire/tests/challenge.robot` — the single
  cumulative suite, four ordered test cases, `Suite Teardown` terminating the
  `aspire run` process tree.
- **Extraction library** (new):
  `tools/track-tester/libraries/assignment_blocks.py` — fence parser + apply
  logic, exposed as Robot keywords (e.g. `Apply Challenge`, `Assert File
  Contains`). Fails loud on an unmapped writable block (see "Coverage
  enforcement" below), so manifest coverage is enforced by the run itself.
- **Variables + manifest** (new):
  `tools/track-tester/variables/dapr_workflow_aspire.py` — working-dir base,
  ApiService port/URLs, expected values, and the per-challenge block→file
  manifest.
- **CI setup script** (new):
  `tools/track-tester/ci/setup-dapr-workflow-aspire.sh` — reproduce the sandbox:
  install uv, .NET 10 SDK, Aspire CLI, Dapr CLI, `dapr init`. No
  diagrid-dashboard pull (dashboard not run). Mirrors the shape of
  `setup-dapr-workflow.sh`.
- **CI workflow** (new): `.github/workflows/test-dapr-workflow-aspire.yml` —
  see below.
- **Reuse** `resources/workflow.resource` + `resources/dapr.resource` where they
  fit: `Start Background Process`, `Wait Until App Responds`, `Wait Until Command
  Output Contains`, `Run And Expect RC Zero`, `Stop Process With SIGINT`.

## Coverage enforcement (fail-loud extraction)

The failure mode unique to extraction: a **new `,copy` file-block added to an
assignment that the manifest does not map** would be silently skipped, and the
build might still pass — hiding real drift.

Reusing `check_doc_sync.py` (even extended to accept `shell` fences) does **not**
guard this, because its whole model is wrong for an extraction-based track: it
asserts each run-command string appears *verbatim in the suite file*, but here
the commands are extracted and run at runtime and never appear in
`challenge.robot` (wrong haystack), and it only inspects run-commands, never the
file-content blocks that carry the real risk.

Rather than add a separate static checker, the **extractor enforces coverage
itself**: when applying a challenge, if it encounters a writable `,copy` block
(`csharp`/`json`/`yaml`/`xml`) whose anchor is not in the manifest, it raises and
the Robot test fails with an explicit "unmapped block" message. This catches the
exact risk as a side effect of the run — no extra script, no extra CI job. The
only thing given up is a fast standalone signal that runs without the full
.NET/Aspire/Docker stack; since the suite runs in CI on the same triggers, that
loss is small.

`check_doc_sync.py` stays **unchanged** (parity with dapr-101/dapr-workflow); it
is simply not used for this track.

## CI workflow (`test-dapr-workflow-aspire.yml`)

Structurally like `test-dapr-workflow.yml`, but single-language:

- **Triggers:** weekly schedule (offset from the other tracks'),
  `workflow_dispatch`, and `pull_request` filtered on `dapr-workflow-aspire/**`
  and `tools/track-tester/**` (plus the workflow file itself).
- **`build-and-run` job** (no matrix): `setup-dotnet` for .NET 10, install the
  Aspire CLI, run `setup-dapr-workflow-aspire.sh` (Dapr + `dapr init`; Docker is
  present on `ubuntu-latest`), `uv sync`, then run the single suite. Upload the
  Robot `results/` as an artifact.
- **`report` job:** on scheduled failure, open/update a `drift-report` issue,
  reusing the pattern in `test-dapr-workflow.yml`.

## Deliberately deferred to implementation (TDD)

Resolved by running locally against a real .NET 10 + Aspire + Dapr environment:

1. **`aspire run` readiness + `/status` shape.** Exact readiness probe for the
   Aspire-orchestrated ApiService on `:5411`, startup timeout, and the JSON
   shape of `GET /status/{id}` used for the completion assertion (the app returns
   `{ state, output }`; confirm whether to assert on a `state` runtime-status
   field or on `output.StarDate`).
2. **Aspire template provisioning in CI.** Whether `dotnet new aspire-starter`
   needs the Aspire project templates installed explicitly in the setup script
   (and at which version) or is provided by the .NET 10 SDK / Aspire CLI.
3. **`.csproj` edits.** The exact keyword/mechanism for the ch2 NuGet adds and
   the ch4 `<Content>` item-group insertion (run-block vs. targeted insert).

## Non-goals

- No dashboard execution, no multi-language matrix, no ch1 suite.
- No changes to `check_doc_sync.py` or to the existing dapr-101 / dapr-workflow
  suites.
- No changes to the `dapr-workflow-aspire` assignment content.
