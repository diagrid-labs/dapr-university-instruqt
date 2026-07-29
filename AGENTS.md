# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository. It explains what
this repo is, how the tracks are laid out, and — in depth — how the `track-tester`
drift-testing harness works so you can run, extend, and debug it confidently.

## What this repo is

This repo is the source of truth for the **Dapr University** tracks hosted on
[Instruqt](https://instruqt.com/). Each top-level folder (except `tools/`) is one track: a
self-paced, browser-based course made of ordered **challenges**. Instruqt renders the
challenge instructions and provisions a sandbox VM; this repo holds the track config,
the `assignment.md` instructions, setup scripts, and (for some tracks) the test suites
that guard against drift.

Learners never run anything locally. The only things executed locally or in CI are the
`track-tester` suites, which reproduce what a learner would do and assert on the results.

## Repository layout

```
<track>/                     one folder per track (see list below)
  README.md                  the track's Instruqt config (name, url, teaser, description…)
  _setup/                    sandbox provisioning scripts run by Instruqt at track start
  <n>-<slug>/                one folder per challenge, in order
    assignment.md            the learner-facing instructions (Markdown + Instruqt annotations)
    notes.md                 author notes (not shown to learners), optional
    images/                  images referenced by assignment.md, optional
    tests/challenge.robot    the drift-test suite for this challenge, optional
tools/
  track-tester/              the Robot Framework drift-testing harness (see below)
  github-collector/          helper tooling (data collection)
.github/workflows/           CI workflows that run the track-tester suites
```

### Tracks

| Folder | What it teaches |
| --- | --- |
| `dapr-101/` | Dapr fundamentals (CLI, state, service invocation, pub/sub). |
| `dapr-workflow/` | Dapr Workflow patterns: durable execution, task chaining, fan-out/fan-in, monitor, external events, child workflows, resiliency/compensation, combined patterns, workflow management. |
| `dapr-workflow-aspire/` | Dapr Workflow built live with .NET Aspire (no upstream repo — the app is pasted from the assignment). |
| `dapr-dotnet-aspire/` | Dapr + .NET Aspire integration. |
| `dapr-agents/` | Dapr Agents fundamentals. |
| `dapr-agents-web-context/` | Dapr Agents Advanced: a Chainlit-powered agent using a `before_llm_call` hook to inject Tavily web-search results. |
| `ai-agents-deepagents/` | Making a [DeepAgents](https://docs.langchain.com/oss/python/deepagents) app durable with Dapr Workflow (Python). |
| `ai-agents-maf/` | Making Microsoft Agent Framework (MAF) agents reliable with Dapr Workflow (.NET Aspire). |
| `catalyst-101/` | Introductory Diagrid Catalyst track. |

Only `dapr-101`, `dapr-workflow`, and `dapr-workflow-aspire` currently have `track-tester`
suites and CI workflows.

## Track & challenge anatomy

- **`<track>/README.md`** is the Instruqt track config, authored as Markdown with headed
  sections (`# Name`, `## Url`, `## Teaser`, `## Time limit (minutes)`, `## Description`,
  etc.). It is not prose documentation — treat the headings as config keys.
- **`_setup/`** holds the sandbox provisioning scripts (e.g. `sandbox-setup.sh`) Instruqt
  runs when a learner starts the track — installing the Dapr CLI, cloning quickstarts,
  running `dapr init`, etc. The `track-tester` CI scripts (below) reproduce this same
  environment so tests run against what learners actually get.
- **`<n>-<slug>/assignment.md`** is the learner-facing instruction file. Its fenced code
  blocks carry **Instruqt annotations** in the info string, comma-separated after the
  language:
  - `run` — renders a *Run* button that executes the command in the sandbox terminal
    (`bash,run`, `curl,run`, `shell,run`).
  - `copy` — renders a *Copy* button (`csharp,copy`, `yaml,copy`); used for code/files the
    learner pastes.
  - `nocopy` — a plain display block, no button (`text,nocopy`, `json,nocopy`).
  - `wrap` — soft-wrap long lines.

  When editing an assignment, keep these annotations intact — the doc-sync checker keys off
  `bash,run` / `shell,run` blocks (see below), and learners rely on the buttons.

When you change assignment commands, expected output, or upstream-dependent steps, update
the matching `tests/challenge.robot` suite too (or the doc-sync CI job will fail).

---

# The `track-tester` harness

`tools/track-tester/` is an end-to-end **drift** test harness built on
[Robot Framework](https://robotframework.org/). The runnable tracks depend on upstream code
(mostly [`dapr/quickstarts`](https://github.com/dapr/quickstarts)); when that upstream code
or the tooling around it changes, a track's `assignment.md` can silently fall out of sync
with the commands and output a learner actually sees. The harness catches this by running
the *actual* commands from each assignment and asserting on their real output.

It also has a **doc-sync** checker that verifies each runnable command in an `assignment.md`
is present in the neighboring suite — so a *new or changed* upstream step can't be added to
an assignment without a corresponding test.

## Directory map

```
tools/track-tester/
  pyproject.toml         project + deps (robotframework 7.x; pytest for unit tests); uv-managed
  uv.lock                locked dependencies
  README.md              human-facing run instructions (local dev, macOS notes, limitations)
  resources/             shared, track-agnostic Robot keywords (the "standard library")
    dapr.resource        generic Dapr process lifecycle + assertions
    workflow.resource    workflow-specific keywords (imports dapr.resource)
    tests/smoke.robot    a smoke suite for the resources themselves
  variables/             shared Python-valued variables imported by suites
    dapr_101.py          QUICKSTARTS_DIR + base dirs for dapr-101
    dapr_workflow.py     QUICKSTARTS_DIR + WF_BASE (tutorials/workflow) for dapr-workflow
    dapr_workflow_aspire.py
  libraries/             Python keyword libraries
    assignment_blocks.py parses ,copy/,run fenced blocks (used by the aspire track,
                         which has no upstream repo and builds the app from the assignment)
    tests/               pytest unit tests for the library
  docsync/
    check_doc_sync.py    the doc-sync presence checker (a standalone Python script)
    tests/               pytest unit tests for it
  ci/                    scripts that reproduce each track's sandbox in CI
    setup-dapr-101.sh
    setup-dapr-workflow.sh
    setup-dapr-workflow-aspire.sh
  results/               (gitignored) output dirs from local/CI runs
```

## How a suite is structured

Each runnable challenge has one suite at `<track>/<n>-<slug>/tests/challenge.robot`. A suite
imports the shared resources/variables by **relative path** back into `tools/track-tester/`,
and defines one test case per language, tagged `dotnet` / `java` / `python` / `javascript`.

Example (`dapr-workflow/3-task-chaining/tests/challenge.robot`, abbreviated):

```robot
*** Settings ***
Name              Ch3 Task Chaining
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch3.log
${OUTPUT}     \\"This is task chaining\\"

*** Test Cases ***
DotNet Task Chaining
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build TaskChaining    ${WF_BASE}/csharp/task-chaining
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/task-chaining    ${LOG}    http://localhost:5255/
    ${id}=    Capture Command Output    <curl … to /start, extract instance id>
    Wait Until Workflow Completed    http://localhost:3555/v1.0/workflows/dapr/${id}    ${OUTPUT}
```

Notes that trip people up:

- **Paths are relative to `tools/track-tester/`**, not to the suite. That's why `robot`
  is always invoked from inside `tools/track-tester/` and suites are addressed as
  `../../<track>/...`.
- **`${WF_BASE}`** etc. come from the `Variables` file and resolve to the quickstarts
  checkout (see variable resolution below).
- **Escaping expected output**: Dapr double-JSON-encodes string workflow outputs, so the
  status response contains escaped inner quotes. In Robot, `\\"` collapses to a single
  backslash-quote at runtime, matching the escaped substring in the real response.
- **A trailing `# doc-sync coverage` comment block** lists commands that the suite performs
  implicitly (via `cwd=` or `bash -c '… && …'`) rather than as literal command strings, so
  the doc-sync checker can still find them. Keep it accurate when you edit a suite.

## Shared keyword libraries

### `resources/dapr.resource` — generic Dapr process lifecycle + assertions

| Keyword | Purpose |
| --- | --- |
| `Start Background Process` | Launch a command non-blocking under an alias, merging stdout+stderr into a fresh log file. |
| `Wait Until Log Contains` | Poll a log file for a substring until it appears or times out (default 60s). |
| `File Should Contain` | Assert a file contains a substring. |
| `Stop Process With SIGINT` | Gracefully stop a background process **and its whole tree**. Sends SIGINT to the process group; if that doesn't stop it, walks the real OS PID tree and SIGKILLs every descendant. This exists because `dapr run` / `daprd` / app processes detach into new process groups and otherwise survive as orphans squatting fixed ports — corrupting the next test. **Do not "simplify" this to a single-PID kill.** |
| `Run And Expect RC Zero` | Run a command to completion; fail unless it exits 0. Returns the result (with `.stdout`). |
| `Assert Command Output Contains` | Run (rc 0) and assert stdout contains a substring. |
| `Run Multi-App And Assert Markers` | Start a multi-app `dapr run -f .` and wait for each expected log marker, then stop. |
| `Assert Redis Keys Contain` | Assert a key exists in the Dapr Redis container via `redis-cli KEYS`. |

### `resources/workflow.resource` — workflow-specific (imports `dapr.resource`)

| Keyword | Purpose |
| --- | --- |
| `Wait Until App Responds` | Language-agnostic readiness probe: curl the app port until the connection succeeds (any HTTP response ⇒ rc 0; refused ⇒ rc 7). Avoids depending on framework log lines. |
| `Start Workflow App` | Start the app in the background, then wait until it responds. |
| `Capture Command Output` | Run (rc 0) and return stripped stdout — used to capture workflow instance IDs from the assignment's curl/grep/sed pipelines. |
| `Wait Until Command Output Contains` | Poll a command until its output contains a substring. |
| `Enable Testcontainers Reuse` | Idempotently set `testcontainers.reuse.enable=true` so the two Java apps in the combined-patterns challenge can share one container. |
| `Wait Until Workflow Completed` | Poll the Dapr workflow status endpoint until `"runtimeStatus":"COMPLETED"`, then optionally assert the output contains an expected substring. |

### `libraries/assignment_blocks.py`

A Python keyword library used by the **aspire** track, which has no upstream repo: every file
the learner creates comes from a `,copy` fenced block and every command from a `shell,run`
block. This module parses those blocks so the suite can reconstruct the app exactly as the
assignment describes — catching drift in the tooling (Aspire CLI, templates) the assignment
depends on.

## Variable resolution (where the code under test comes from)

The `variables/*.py` files resolve the quickstarts checkout used by the suites:

```python
QUICKSTARTS_DIR = os.environ.get("QUICKSTARTS_DIR") or os.path.expanduser("~/quickstarts")
WF_BASE = os.path.join(QUICKSTARTS_DIR, "tutorials", "workflow")
```

- If `QUICKSTARTS_DIR` is set, suites use that checkout (CI sets it; locally you can point it
  at an existing clone). Otherwise they fall back to `~/quickstarts`, where the `ci/` setup
  scripts clone the repo.
- No `--variable` flag is needed — the suites read the env var directly via these files.

## doc-sync

`docsync/check_doc_sync.py` is a standalone script asserting every **runnable** command in an
`assignment.md` appears in the neighboring suite (a *presence* check, not proof of execution).

- A fenced block counts as runnable only when its info string is `bash` with a `run` flag
  (e.g. ` ```bash,run `). A plain ` ```bash ``` ` block is not required to be covered.
- `<summary>…</summary>` language markers map a command to a language (`.NET`→dotnet,
  `Python`→python, `Java`→java, `JavaScript`→javascript; longest key first so "JavaScript"
  wins over "Java").
- Commands performed via `cwd=`/`bash -c` in the suite are covered by the trailing
  `# doc-sync coverage` comment lines in the suite.

Run it:

```bash
(cd tools/track-tester && uv run python docsync/check_doc_sync.py \
  ../../dapr-101/4-service-invocation-api/assignment.md \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)
```

## Running the harness

Everything runs from **`tools/track-tester/`** via `uv` (so paths to suites are
`../../<track>/...`). The examples wrap that in a subshell so you can paste from the repo root.

```bash
# One-time: reproduce the sandbox (clones dapr/quickstarts to ~/quickstarts, installs the
# Dapr CLI, runs `dapr init` — this re-inits your local Dapr). Needs Docker running.
bash tools/track-tester/ci/setup-dapr-101.sh        # dapr-101 (pins the Dapr CLI version)
bash tools/track-tester/ci/setup-dapr-workflow.sh   # dapr-workflow (Dapr CLI from master)

# Optional: point suites at an existing checkout instead of ~/quickstarts.
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"

# Sync harness deps.
(cd tools/track-tester && uv sync)

# Run one challenge (all languages).
(cd tools/track-tester && uv run robot ../../dapr-workflow/3-task-chaining/tests/challenge.robot)

# Run a whole track; --name gives the combined run a clean title.
(cd tools/track-tester && uv run robot --name "Dapr Workflow" ../../dapr-workflow/*/tests/challenge.robot)

# Filter by language tag (--include/--exclude, repeatable; --include ORs).
(cd tools/track-tester && uv run robot --include python ../../dapr-workflow/*/tests/challenge.robot)

# Dry run (resolve syntax/keywords, run nothing — fast, no Docker/Dapr).
(cd tools/track-tester && uv run robot --dryrun ../../dapr-workflow/*/tests/challenge.robot)

# Choose an output dir (Robot writes output.xml/log.html/report.html there).
(cd tools/track-tester && uv run robot --outputdir results/ch3 ../../dapr-workflow/3-task-chaining/tests/challenge.robot)

# Merge separate runs into one indexed report (as CI does).
(cd tools/track-tester && uv run rebot --outputdir results/combined --name dapr-workflow results/*/output.xml)

# Harness unit tests (docsync + libraries).
(cd tools/track-tester && uv run pytest -v)
```

See `tools/track-tester/README.md` for the full run reference, macOS caveats (Docker daemon,
Homebrew-vs-`/usr/local/bin` Dapr shadowing, per-language runtime notes), and limitations.

## CI workflows

Three workflows in `.github/workflows/` run the suites automatically. Each triggers on a
**daily schedule**, on **`workflow_dispatch`**, and on **pull requests** touching the track,
the harness (`tools/track-tester/**`), or the workflow file. On failure, a `report` job
opens or updates a single **`drift-report`** GitHub issue that names the failing legs and
gives `gh run download` commands for the Robot reports.

| Workflow | Track | Schedule (UTC) | Jobs / matrix |
| --- | --- | --- | --- |
| `test-dapr-101.yml` | `dapr-101` | 06:00 daily | doc-sync; agnostic (ch2–3); per-language matrix: dotnet, python, java, javascript |
| `test-dapr-workflow.yml` | `dapr-workflow` | 06:15 daily | doc-sync (all challenges); per-language matrix: dotnet, java, python |
| `test-dapr-workflow-aspire.yml` | `dapr-workflow-aspire` | 06:30 daily | harness unit tests (pytest); build-and-run (.NET 10 + Aspire CLI) |

Details worth knowing when editing CI:

- **Sandbox setup** is done by `tools/track-tester/ci/setup-*.sh`; **language runtimes** are
  provisioned by the workflow's `setup-dotnet`/`setup-java`/`setup-python`/`setup-node` steps,
  not by the setup scripts.
- The dapr-workflow **Java** leg caches `~/.m2` and **pre-warms Maven deps outside the timed
  run** — the Java challenges start via `mvn spring-boot:test-run` under a 300s readiness
  timeout, and a cold `~/.m2` download would otherwise eat into compile+startup time.
- The aspire workflow does **not** install the Aspire project templates itself: the suite's
  first checkpoint runs the pinned `dotnet new install Aspire.ProjectTemplates@<ver>` command
  extracted from the assignment, keeping the pinned version a single source of truth (and
  catching drift in it).
- Each per-language leg runs **every** challenge even if an earlier one fails (the `if !`
  guard is exempt from `set -e`), writes a `failed-<leg>.txt` summary, merges per-challenge
  results with `rebot`, and uploads a `robot-<lang>` artifact.

## Conventions & gotchas for agents

- **Run `robot`/`rebot`/`pytest` from `tools/track-tester/`** (via `uv run`). Suite paths are
  relative to that directory.
- **Never simplify `Stop Process With SIGINT`** to a single-PID kill — the tree-kill fallback
  is load-bearing on Linux CI (orphaned `daprd`/app processes squat fixed ports).
- **Keep assignment annotations and the `# doc-sync coverage` comments in sync** with the
  suite; otherwise the doc-sync job fails.
- **A drift-test failure is often a *correct* signal**, not a harness bug — upstream
  quickstarts changed, or an assignment's expected output no longer matches. Read the failing
  Robot `report.html`/`log.html` before assuming the test is wrong.
- **`dapr-workflow-aspire` ch1 is not pure-reading**: its suite runs the pinned
  `Aspire.ProjectTemplates` install; that version pin matters (a known-bad range breaks the
  `0.0.0.0` binding).
- Only edit tracks in place and push to the relevant Instruqt track — there is no local
  "run the track" path for learners.
