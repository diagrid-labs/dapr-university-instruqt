# dapr-workflow drift tests — design

## Goal

Add Robot Framework drift tests for the `dapr-workflow` track, following the
existing `dapr-101` harness (`tools/track-tester/`). The tests run the actual
commands a learner runs and assert on their output, so drift between the track's
`assignment.md` files and the upstream `dapr/quickstarts` code they depend on is
caught automatically.

## Scope

- **Challenges:** the 9 runnable challenges, `2`–`10`. Challenges `1`
  (durable-execution) and `11` (challenges-and-tips) are conceptual and have no
  runnable commands — no suites.
- **Languages:** .NET, Java, Python (the track has no JavaScript).
- **Harness parity with dapr-101:** Robot suites + a shared resource file +
  a variables file + docsync coverage + a GitHub Actions workflow.

## Key facts (verified against the local quickstarts checkout)

- **Code source:** `${QUICKSTARTS_DIR}/tutorials/workflow/{csharp,java,python}/<pattern>`
  — *not* the top-level `workflows/` quickstart. The track's
  `dapr-workflow/_setup/sandbox-setup.sh` clones `dapr/quickstarts` and runs
  `dapr init`, and installs the Dapr CLI from `master` (no pinned version).
- **Interaction model** (differs fundamentally from dapr-101's "run multi-app,
  wait for log markers"): build → start app in background → wait until ready →
  `POST /start` (capturing an instance id) → `GET` workflow status and assert
  `COMPLETED` + output → optional extra ops → stop.
- **Java is architecturally different** from .NET/Python:
  - .NET/Python: `dapr run -f .`, and interact with the **Dapr workflow
    management API** at `:<daprHTTPPort>/v1.0/workflows/dapr/<id>`.
  - Java: `mvn spring-boot:test-run` (Testcontainers-based Dapr), app on port
    `8080`, no `dapr run`, no separate Dapr HTTP port; interaction via
    **app-owned endpoints** (`/start`, `/output`, `/status`, `/event`).

### Port / appID map (.NET & Python `dapr.yaml`)

| Ch | Pattern (folder)                     | appID(s)                     | appPort | daprHTTPPort |
|----|--------------------------------------|------------------------------|---------|--------------|
| 2  | `fundamentals`                       | `basic`                      | 5254    | 3554         |
| 3  | `task-chaining`                      | `chaining`                   | 5255    | 3555         |
| 4  | `fan-out-fan-in`                     | `fanoutfanin`                | 5256    | 3556         |
| 5  | `monitor-pattern`                    | `monitor`                    | 5257    | 3557         |
| 6  | `external-system-interaction(s)`     | `externalevents`             | 5258    | 3558         |
| 7  | `child-workflows`                    | (child workflows)            | 5259    | 3559         |
| 8  | `resiliency-and-compensation`        | (resiliency)                 | 5264    | 3564         |
| 9  | `combined-patterns`                  | `order-workflow` + `shipping`| 5260 / 5261 | 3560 / 3561 |
| 10 | `workflow-management`                | `neverendingworkflow`        | 5262    | 3562         |

Java always uses port `8080`. Note the folder-name mismatch across languages for
ch6: csharp `external-system-interaction`, java `external-system-interactions`
(plural), python `external-system-interaction`.

## Layout

Mirrors dapr-101. New/changed files:

- **Suites** (new): `dapr-workflow/<n>-<name>/tests/challenge.robot`, one per
  runnable challenge (2–10).
- **Shared keywords** (new): `tools/track-tester/resources/workflow.resource`.
  Imports the existing `dapr.resource` for the generic process/assertion
  keywords (`Start Background Process`, `Wait Until Log Contains`,
  `Run And Expect RC Zero`, `Assert Command Output Contains`,
  `Stop Process With SIGINT`) and adds workflow-specific keywords. Keeps
  `dapr.resource` generic rather than bloating it.
- **Shared variables** (new): `tools/track-tester/variables/dapr_workflow.py`.
  Reuses the same `QUICKSTARTS_DIR` resolution (env var → `~/quickstarts`), adds
  `WF_BASE = <QUICKSTARTS_DIR>/tutorials/workflow` and per-language readiness
  markers.
- **CI setup script** (new): `tools/track-tester/ci/setup-dapr-workflow.sh`.
  Clone quickstarts, install uv, install the Dapr CLI, `dapr init`. No version
  pin (the track does not assert a pinned version).
- **CI workflow** (new): `.github/workflows/test-dapr-workflow.yml`, mirroring
  `test-dapr-101.yml`.

## New keywords (`workflow.resource`)

- `Start Workflow App` — start the run command in the background under an alias
  and wait for a readiness marker in the log.
- `Post Start And Capture Instance Id` — POST the start URL and return the
  instance id, extracted from the **Location header** (.NET) or the
  **`instance_id` JSON body** (Python) via a `mode` argument.
- `Wait Until Workflow Completed` — poll the Dapr workflow API
  (`GET :<daprHTTPPort>/v1.0/workflows/dapr/<id>`) until `runtimeStatus`
  matches (default `COMPLETED`) and, optionally, the output contains an expected
  value.
- `Raise Workflow Event` — POST `.../raiseEvent/<name>` on the Dapr API.
- Java: app-owned endpoints are exercised with the existing
  `Assert Command Output Contains` plus one thin polling helper (e.g.
  `Wait Until Output Contains` that polls `GET :8080/output`).

## Suite structure

Each suite has three tagged test cases: `[Tags] dotnet`, `[Tags] java`,
`[Tags] python` (so CI can `--include <lang>`), following the dapr-101 pattern.
Per-challenge `${BASE}`, ports, and expected outputs live in the suite's
`*** Variables ***`; shared values come from `dapr_workflow.py`.

### Per-language execution

- **.NET:** `dotnet build <Proj>` → `dapr run -f .`; id from Location header;
  status via Dapr API.
- **Python:** `python3 -m venv venv && source venv/bin/activate &&
  pip3 install -r requirements.txt` → `dapr run -f .` (from the parent dir). The
  venv activation must carry into `dapr run` — implemented as a single `bash -c`
  chain (or by pointing the run at the venv's interpreter); resolved during
  implementation.
- **Java:** `mvn spring-boot:test-run`; interact via app endpoints on `:8080`.

### Per-challenge assertion specifics

- **ch2, ch3, ch4, ch7, ch8:** standard start → `COMPLETED` → assert output.
- **ch5 monitor:** recurring workflow — assert app-log markers
  (`CheckStatus`/`check_status: Received input:`) appear, then eventual
  `COMPLETED`.
- **ch6 external-events:** start (`RUNNING`) → raise `approval-event`
  (Dapr API for .NET/Python at `:3558`; app `/event` for Java) → `COMPLETED`.
  Fixed instance id (`b7dd836b-...`, the order id).
- **ch9 combined-patterns:** two apps. .NET/Python run both via one
  `dapr run -f .`; **Java runs two separate `mvn` background processes** with
  `-Dspring-boot.run.arguments="--reuse=true"` (two aliases). Fixed instance id
  (`b0d38481-...`).
- **ch10 workflow-management:** never-ending workflow — start `/start/0` →
  suspend → resume → terminate → purge (assert HTTP success on each). No
  `COMPLETED` assertion.

## docsync

Reuse `tools/track-tester/docsync/check_doc_sync.py` unchanged. It only treats
`bash,run` fences as runnable, so each suite carries the assignment's
`bash,run` commands (cd/build/venv/pip/run) verbatim, or `# doc-sync coverage`
comments for cwd-expressed / setup-performed steps — exactly as dapr-101 does.
`curl,run` blocks are not docsync-checked (same as dapr-101); the executing
suites are what catch curl / port / endpoint drift.

## CI workflow (`test-dapr-workflow.yml`)

Mirrors `test-dapr-101.yml`:

- Triggers: weekly schedule, `workflow_dispatch`, and `pull_request` filtered on
  `dapr-workflow/**` and `tools/track-tester/**`.
- `docsync` job: loop the 9 challenges through `check_doc_sync.py`.
- `languages` job: matrix `dotnet` / `java` / `python`; set up the runtime
  (`setup-dotnet` / `setup-java` / plain Python), run
  `setup-dapr-workflow.sh`, then run all 9 suites with `--include <lang>`.
  Java's Testcontainers-based Dapr needs Docker (present on `ubuntu-latest`);
  .NET/Python need `dapr init` from the setup script.
- `report` job: on scheduled failure, open/update a `drift-report` issue.

## Deliberately deferred to implementation (TDD)

Two details will be resolved by running against the local quickstarts checkout
(`QUICKSTARTS_DIR=$HOME/dev/dapr/quickstarts`) and observing real output:

1. The exact per-language readiness log markers.
2. The Python venv-activation-into-`dapr-run` mechanics.

## Non-goals

- No JavaScript (not in the track).
- No changes to `check_doc_sync.py` (curl coverage stays out of scope; parity
  with dapr-101).
- No changes to the dapr-101 suites or the `dapr-workflow` assignment content.
