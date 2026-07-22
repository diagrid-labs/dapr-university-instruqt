# track-tester

End-to-end drift tests for Dapr University tracks, built on [Robot Framework](https://robotframework.org/).
The tests run the *actual* commands a learner runs and assert on their output, so that drift between a
track's `assignment.md` files and the upstream code they depend on (e.g. `dapr/quickstarts`) is caught
automatically.

## Layout

- `resources/` — shared, track-agnostic Robot keywords (Dapr process lifecycle, assertions).
- `variables/` — shared values (quickstarts base dir, expected output markers).
- `docsync/` — a Python checker asserting each assignment's commands are covered by a suite.
- `ci/` — scripts that reproduce a track's sandbox environment in CI.

Each runnable challenge's suite lives next to its `assignment.md`, e.g.
`dapr-101/4-service-invocation-api/tests/challenge.robot`.

## Running locally

`robot`/`rebot`/`uv`/doc-sync commands run from **`tools/track-tester/`**, so paths to
suites are written relative to that directory (`../../<track>/...`). The examples wrap
that in a subshell: `(cd tools/track-tester && …)`, so you can paste them from the repo root.

### Setup

```bash
# One-time: reproduce the sandbox environment. Clones dapr/quickstarts to ~/quickstarts,
# installs the pinned Dapr CLI, and runs `dapr init` (this re-inits your local Dapr).
bash tools/track-tester/ci/setup-dapr-101.sh     # dapr-101 (pins the Dapr CLI version)
bash tools/track-tester/ci/setup-dapr-workflow.sh # dapr-workflow (installs Dapr CLI from master)

# Optional: point the suites at an existing quickstarts checkout instead of ~/quickstarts.
# The suites read this env var directly (via variables/*.py); no --variable needed.
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
```

### Specifying which track / challenges to run

A "track" is a top-level folder (`dapr-101`, `dapr-workflow`); each challenge's suite is
`<track>/<n>-<name>/tests/challenge.robot`. Point `robot` at one suite, several, or a whole
track via a glob. Passing multiple suites to a **single** `robot` invocation produces one
combined `report.html`/`log.html` that indexes every suite (the local equivalent of what CI
builds with `rebot`).

```bash
# one challenge (all its languages)
(cd tools/track-tester && uv run robot \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)

# several specific challenges
(cd tools/track-tester && uv run robot \
  ../../dapr-workflow/3-task-chaining/tests/challenge.robot \
  ../../dapr-workflow/6-external-events/tests/challenge.robot)

# a whole track — the glob matches only challenges that have a suite (2–10 here);
# one invocation ⇒ one report.html indexing every challenge
(cd tools/track-tester && uv run robot --name "Dapr Workflow" \
  ../../dapr-workflow/*/tests/challenge.robot)

# both tracks at once
(cd tools/track-tester && uv run robot --name "Dapr University" \
  ../../dapr-101/*/tests/challenge.robot ../../dapr-workflow/*/tests/challenge.robot)
```

When you pass multiple suites, Robot names the combined run by joining the child suite
names with ` & ` (e.g. `Ch2 Fundamentals & Ch3 Task Chaining & …`). Pass `--name` to give
the combined run a clean top-level title instead.

### Selecting a language (tag)

Each suite has three tests tagged `dotnet` / `java` / `python`. Filter with `--include` /
`--exclude` (repeatable):

```bash
# only the Python tests, across the whole dapr-workflow track
(cd tools/track-tester && uv run robot --include python ../../dapr-workflow/*/tests/challenge.robot)

# dotnet OR java (repeat --include; it ORs)
(cd tools/track-tester && uv run robot --include dotnet --include java \
  ../../dapr-workflow/3-task-chaining/tests/challenge.robot)

# everything except java (e.g. no Testcontainers locally)
(cd tools/track-tester && uv run robot --exclude java ../../dapr-workflow/*/tests/challenge.robot)

# a single test case by name
(cd tools/track-tester && uv run robot --test "Python Task Chaining" \
  ../../dapr-workflow/3-task-chaining/tests/challenge.robot)
```

### Specifying the output path

By default Robot writes `output.xml`, `log.html`, and `report.html` into the **current
directory** (`tools/track-tester/`). Redirect them with `--outputdir` (base dir for all three)
and/or the individual `--output` / `--log` / `--report` flags (resolved under `--outputdir`):

```bash
# put all artifacts under results/wf-python/
(cd tools/track-tester && uv run robot --include python \
  --outputdir results/wf-python ../../dapr-workflow/*/tests/challenge.robot)

# name the individual artifacts explicitly (pass NONE for any you want to skip,
# e.g. --output NONE to keep only the HTML report/log)
(cd tools/track-tester && uv run robot \
  --outputdir results/ch3 --report report.html --log log.html \
  ../../dapr-workflow/3-task-chaining/tests/challenge.robot)
```

### Combining separate runs into one indexed report

If you ran challenges into separate output dirs (as CI does, one per challenge), merge their
`output.xml` files into a single indexed `report.html`/`log.html` with `rebot`:

```bash
(cd tools/track-tester && uv run rebot \
  --outputdir results/combined --name "dapr-workflow" \
  results/*/output.xml)
```

### Validate without executing, and doc-sync

```bash
# dry run: resolve syntax + keywords/variables without running anything (fast, no Docker/Dapr)
(cd tools/track-tester && uv run robot --dryrun ../../dapr-workflow/*/tests/challenge.robot)

# doc-sync: assert every runnable command in an assignment.md is covered by its suite
(cd tools/track-tester && uv run python docsync/check_doc_sync.py \
  ../../dapr-101/4-service-invocation-api/assignment.md \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)
```

## Local development on macOS

The `ci/setup-dapr-101.sh` script is written for the **Ubuntu CI runner** — it reproduces the Instruqt
sandbox from scratch (clone quickstarts, install the pinned Dapr CLI, `dapr init`). On macOS it works,
but two things bite:

- **`dapr init` needs the Docker daemon running** (it starts the Redis/placement/scheduler/zipkin
  containers).
- **Dual `dapr` installs shadow each other.** Dapr's `install.sh` (which the script pipes to) installs
  to `/usr/local/bin`, but if you also have Dapr from Homebrew (`/opt/homebrew/bin`), Homebrew's copy
  comes **first** on `PATH` on Apple Silicon. The script's version check reads whichever `dapr` is
  first on `PATH` (the Homebrew one); if that version differs from the pinned one, the script
  reinstalls to `/usr/local/bin` every run — where it stays shadowed. Result: a reinstall loop that
  never changes the `dapr` your shell actually resolves.

**Recommended for local suite development: skip the setup script's installer entirely.** You almost
certainly already have Docker and a Dapr CLI. Just point the suites at a quickstarts checkout and use
your existing Dapr:

```bash
# Ensure Docker is running, then initialize Dapr once:
dapr init

# Point the suites at your quickstarts checkout (or ~/quickstarts):
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"

# Run a suite (challenges 3/4/5 don't care about the exact CLI version):
(cd tools/track-tester && uv run robot --include python \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)
```

Only **challenge 2** asserts the exact pinned version (`1.18.0`). If your local `dapr` differs, that
suite will report a version mismatch — which is a *correct* signal, not a bug. Either skip it locally
(run the other challenges) or bring your Dapr to the pinned version. If you manage Dapr with Homebrew,
`brew upgrade dapr` is the clean way to do that (it updates the `dapr` your `PATH` actually resolves,
avoiding the shadowing problem above).

### dapr-workflow: per-language runtime notes

The dapr-workflow suites share `resources/workflow.resource` + `variables/dapr_workflow.py`
and run exactly like the examples above. Two per-language quirks to know:

- **.NET / Python** use `dapr run -f .` and therefore need `dapr init` to have run (sidecar +
  Redis/placement/scheduler containers). They interact with the Dapr workflow API.
- **Java** uses `mvn spring-boot:test-run` (Testcontainers-based Dapr) — it needs the Docker
  daemon but **not** `dapr run`, and talks to app-owned endpoints on port 8080. So you can run
  the .NET/Python legs with just `dapr init`, but the `java` leg additionally needs Docker able
  to pull the Testcontainers images.

## Limitations

- doc-sync is a *presence* check: it verifies each assignment command string appears in the
  neighboring suite (including `# doc-sync coverage` comments used for setup-performed or
  `cwd`-expressed commands); it does not prove every command is executed and asserted. Its job is
  catching *new/changed* upstream steps, not guaranteeing full behavioral coverage.
- doc-sync only treats a fenced block as runnable when its info string is `bash` with a `run` flag
  (e.g. ` ```bash,run `); a plain ` ```bash ``` ` block is not required to be covered.
- Language runtimes in CI are provisioned per matrix language by the workflow's runtime-setup
  steps — `setup-dotnet`/`setup-java`/`setup-node` for dapr-101, and
  `setup-dotnet`/`setup-java`/`setup-python` for dapr-workflow — not by the setup script.
