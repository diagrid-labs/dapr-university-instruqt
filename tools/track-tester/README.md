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

All commands below are run from the repository root.

```bash
# One-time: reproduce the sandbox environment. Clones dapr/quickstarts to ~/quickstarts,
# installs the pinned Dapr CLI, and runs `dapr init` (this re-inits your local Dapr).
bash tools/track-tester/ci/setup-dapr-101.sh

# Optional: point the suites at an existing quickstarts checkout instead of ~/quickstarts.
# The suites read this env var directly (via variables/dapr_101.py); no --variable needed.
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"

# run one challenge suite for one language
(cd tools/track-tester && uv run robot --include python \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)

# validate a suite without executing it (syntax + keyword resolution)
(cd tools/track-tester && uv run robot --dryrun \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)

# doc-sync check
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

## Limitations

- doc-sync is a *presence* check: it verifies each assignment command string appears in the
  neighboring suite (including `# doc-sync coverage` comments used for setup-performed or
  `cwd`-expressed commands); it does not prove every command is executed and asserted. Its job is
  catching *new/changed* upstream steps, not guaranteeing full behavioral coverage.
- doc-sync only treats a fenced block as runnable when its info string is `bash` with a `run` flag
  (e.g. ` ```bash,run `); a plain ` ```bash ``` ` block is not required to be covered.
- Language runtimes in CI are provisioned by the workflow's `setup-dotnet`/`setup-java`/`setup-node`
  steps (per matrix language), not by the setup script.
