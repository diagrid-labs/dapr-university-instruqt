# Design — Automated Drift-Test Framework for the Dapr 101 Track

An automated end-to-end test framework that detects when the Dapr 101 track's learner-facing
instructions have drifted out of sync with the external code they depend on (primarily the
[`dapr/quickstarts`](https://github.com/dapr/quickstarts) repository and the pinned Dapr CLI/runtime).
It runs on GitHub Actions weekly and on demand, exercises the actual commands a learner runs, across
all four language variations, and reports drift as a GitHub issue.

Designed for **dapr-101** first, with a shared harness intended for reuse by the other tracks later.

---

## 1. Problem & goals

The tracks in this repo depend mostly on other GitHub repos. `dapr-101` clones `dapr/quickstarts` at
sandbox startup and then instructs learners to run real applications from it (`csharp/http`,
`python/sdk`, `java/http`, `javascript/sdk`, …) using per-language build/run commands. When the
quickstarts repo changes — folder paths move, build commands change, dependencies break, app output
changes — or when the pinned Dapr version diverges, the assignment instructions silently become wrong.
Nothing today catches this.

### Sources of drift for dapr-101

| Source | Where it lives | Example |
| --- | --- | --- |
| Quickstart folder paths | `assignment.md` build/run commands | `dotnet build csharp/http/checkout` |
| Per-language build/run commands | `assignment.md` `<details>` blocks | `uv sync --all-packages`, `mvn clean install`, `npm install`, `dapr run -f .` |
| Inline YAML shown to learners | `assignment.md` (`dapr.yaml`, `pubsub.yaml`, `statestore.yaml`) | may diverge from the real repo files |
| Expected application output | `assignment.md` expected-output blocks | `Order received`, `Subscriber received` |
| Pinned Dapr CLI / runtime version | `_setup/sandbox-setup.sh` | `DAPR_CLI_VERSION 1.18.0` |
| Setup-script steps | `_setup/*.sh` | runtime installs, `dapr init` |

### Goals

- **Full-execution fidelity.** Actually run the assignment's commands in a sandbox-equivalent
  environment and assert the apps start and produce the expected key markers. This catches every kind
  of drift above, including runtime failures a static check would miss.
- **All language variations.** Cover .NET, Python, Java, and JavaScript for the language-variant
  challenges.
- **All runnable challenges (2–5).** Challenge 1 is pure theory with no commands, so nothing to run.
- **Test lives next to the markdown, not inside it.** No annotations embedded in `assignment.md`.
- **Runs weekly + on demand** on GitHub Actions, and reports drift as an actionable GitHub issue.

### Non-goals

- No changes to the learner-facing `assignment.md` content or format (the tests are external).
- No Instruqt-native testing (`instruqt track test`) in v1 — documented as a future enhancement.
- No coverage of tracks other than dapr-101 in v1 (the harness is built to be reusable, but only
  dapr-101 suites ship first).
- No static-only "paths exist / YAML matches" checking as the primary mechanism — execution is the
  ground truth. (Version-string and marker assertions are byproducts of execution, not a separate
  static pass.)

---

## 2. Engine choice: Robot Framework

The hard requirement is orchestrating **several concurrent long-running processes** — a Dapr sidecar
that must stay alive while curl/Redis commands run in "another terminal", and `dapr run -f .` whose
streaming logs are asserted on before a Ctrl+C — plus a four-language matrix, with the spec living
beside the markdown.

[Robot Framework](https://robotframework.org/) (actively maintained, v7.x) is the chosen engine:

- Its standard **`Process`** library is purpose-built for this: `Start Process` (background),
  `Run Process` (foreground, returns `.stdout`/`.stderr`/`.rc`), `Send Signal To Process SIGINT`,
  `Wait For Process`, `Terminate Process`/`Terminate All Processes`, process groups, and timeouts.
- Its **`OperatingSystem`** library covers file/log inspection (`File Should Contain`, `Run`).
- Assertion keywords (`Should Contain`, `Should Match Regexp`) do substring/regex matching — exactly
  the **key-marker, order-agnostic** matching needed for async pub/sub output.
- Specs are declarative `.robot` files that live next to each `assignment.md`.
- First-class **xUnit / `log.html` / `report.html`** output feeds the drift issue.

### Alternatives considered

- **mechanical-markdown** (Dapr's own markdown validator) — rejected: unmaintained, and embeds
  annotations *inside* the markdown, which the maintainer does not want.
- **pytest + pexpect** — viable and matches the repo's existing uv/pytest stack, but hand-rolls the
  process orchestration that Robot provides out of the box.
- **venom** (YAML e2e) — clean and declarative, but weak at keeping background processes alive across
  steps and asserting on streaming logs — exactly the hardest part here.
- **bats-core** — mature and CI-native, but background long-runners require manual FD/PID juggling and
  async assertions are DIY.
- **hurl** — excellent for HTTP, but HTTP-only; cannot start the sidecar or apps. Could be a
  complementary tool for challenge 3 later; not used in v1 to keep the toolchain single-engine.

---

## 3. Architecture overview

Four cooperating GitHub Actions jobs:

```
Weekly cron / manual dispatch / pull_request
        │
        ├─ job: docsync     (fast, no env)   ── every assignment's commands are covered by a suite
        ├─ job: agnostic    (1 runner)       ── setup+init → challenge 2 & 3 suites (no lang filter)
        ├─ job: languages   (4× matrix)      ── setup+init → challenge 4 & 5 suites, --include <lang>
        │        dotnet │ python │ java │ javascript
        └─ job: report      (if: failure)    ── open/update a "drift detected" GitHub issue
```

- **Robot Framework** executes each runnable challenge's `.robot` suite.
- **Shared, track-agnostic keywords** (start/stop Dapr sidecar, run multi-app template,
  wait-for-log-marker, assert Redis keys) live in a shared harness so each suite stays small.
- A **doc-sync check** keeps each suite honest to its neighboring assignment.

The `pull_request` trigger (scoped by path) is included so drift and broken tests are caught before
merge, in addition to the weekly cron and manual dispatch.

---

## 4. Directory layout

```
tools/track-tester/                 # shared, reusable across all tracks
  pyproject.toml                    # uv-managed; dependency: robotframework
  resources/
    dapr.resource                   # Start Dapr Sidecar, Run Multi-App Template,
                                     #   Wait Until Log Contains, Send SIGINT, Assert Redis Keys, ...
    setup.resource                  # env-bootstrap keywords
  variables/
    dotnet.yaml  python.yaml        # per-language dir / build cmd / run cmd values
    java.yaml    javascript.yaml
  docsync/
    check_doc_sync.py               # extract bash,run cmds from md -> assert covered by suite
    tests/                          # pytest unit tests for the checker
  ci/
    setup-dapr-101.sh               # wraps the real _setup scripts (adapts Instruqt-only bits)
  README.md

dapr-101/
  2-dapr-cli/tests/challenge.robot
  3-state-management-api/tests/challenge.robot
  4-service-invocation-api/tests/challenge.robot     # language-tagged tests
  5-pubsub-api/tests/challenge.robot
```

`.robot` suites live in a `tests/` folder inside each challenge, adjacent to `assignment.md` and
mirroring the existing `scripts/` convention. They are not referenced by any Instruqt config, so they
are inert to the learner experience.

---

## 5. How a challenge maps to a Robot suite

Drift-prone parts (folder paths, build/run commands, expected markers) are expressed **declaratively
as Robot steps** using shared keywords. The concurrent-long-running-process crux maps directly onto
the `Process` library.

### Challenge 3 (sidecar in background + curl + Redis), illustrative

```robotframework
*** Settings ***
Resource          ../../../tools/track-tester/resources/dapr.resource
Suite Teardown    Terminate All Processes    kill=True

*** Test Cases ***
State Management API Round-Trip
    Start Dapr Sidecar    app_id=myapp    http_port=3500    alias=sidecar
    Wait Until Log Contains    sidecar    You're up and running!    timeout=60s
    Run Curl POST    localhost:3500/v1.0/state/statestore    [{"key":"name","value":"Bruce Wayne"}]
    ${r}=    Run Curl GET     localhost:3500/v1.0/state/statestore/name
    Should Contain    ${r.stdout}    Bruce Wayne
    Assert Redis Keys Contain    myapp||name
    Send Signal To Process    SIGINT    sidecar
    Wait Until Log Contains    sidecar    Exited Dapr successfully    timeout=15s
```

### Challenge 2 (CLI install/init/version) assertions

- `Run Process dapr --version` → `.rc == 0` and `Should Contain … CLI version: <pinned>` /
  `Runtime version: <pinned>`, where `<pinned>` is read from `_setup/sandbox-setup.sh`. This catches
  version drift.
- `Run docker ps --format {{.Names}}` → `Should Contain dapr_placement / dapr_scheduler / dapr_redis /
  dapr_zipkin`.

### Challenges 4 & 5 (language matrix)

- Each language is a tagged test case (`[Tags] python`), so CI runs `robot --include python …`.
- Per-language `dir` / `build command` / `run command` values come from a language variable file in
  `tools/track-tester/variables/` (e.g. `python.yaml`), keeping the drift-prone values in one obvious
  place per language.
- Flow: run the build/install commands foreground (assert `.rc == 0`) → `Start Process dapr run -f .`
  in background with `stdout` captured → wait until the log contains the key markers (`Order received`
  and `Order passed` for service invocation; publish/subscribe markers for pub/sub) →
  `Send Signal To Process SIGINT` → terminate.
- `Suite Teardown → Terminate All Processes kill=True` guarantees a hung sidecar or app never wedges
  the CI runner.

### Matching strategy

Assertions are **substring / regex, order-agnostic** (`Should Contain`, `Should Match Regexp`): assert
that characteristic markers appear, not a byte-exact block. This tolerates async ordering and loop
counts, avoiding false failures while still catching real output drift.

---

## 6. Doc-sync check

`check_doc_sync.py <assignment.md> <challenge.robot>`:

1. Parse the markdown and extract every fenced block whose info string contains `run`
   (```` ```bash,run ````, `bash,run,copy`), grouping commands by the enclosing
   `<details><summary>Run the X apps</summary>` into per-language buckets.
2. Normalize whitespace and assert each extracted command appears in the neighboring `.robot` suite
   (and its language variable file). Report any assignment command **not** covered; warn on suite
   commands that no longer appear in the doc.

This is a lightweight coverage guard, not a shell parser. It catches "a step was added or changed in
the assignment but not in the test" — the divergence risk introduced by keeping the spec outside the
markdown. It runs in its own fast job that needs no environment, and fails the build fast when
coverage is incomplete.

Exit codes: `0` all commands covered; `1` one or more assignment commands uncovered (with a report of
which); `2` usage/parse error.

---

## 7. CI environment provisioning

`ci/setup-dapr-101.sh` **wraps the real `_setup` scripts** (`image-dapr-101-install.sh` and
`sandbox-setup.sh`) rather than duplicating them, adapting only the Instruqt-specific bits:

- `agent variable set DAPR_CLI_VERSION …` → export as env / parse the pinned value for assertions.
- `docker login -u ${DockerUSER} …` → skipped, or supplied from CI secrets if rate limits require it.

It clones `dapr/quickstarts`, installs the required runtime(s), installs the Dapr CLI at the pinned
version, and runs `dapr init`. Because it invokes the real setup scripts, **drift in the setup scripts
themselves is also exercised.**

- The **agnostic** job runs the full runtime install and covers challenges 2 and 3.
- The **language matrix** jobs install only their own runtime (for speed) plus Dapr, then run their
  language's challenge 4 & 5 suites.

Both job types run `dapr init` before executing suites (challenges 3–5 depend on the Redis/scheduler
containers it starts).

---

## 8. Failure reporting

The `report` job runs `if: failure()`:

- Uses a **stable issue title** (`Dapr 101 track drift detected`) and a `drift-report` label.
- Finds the existing open issue with that title/label and updates it, or creates it if absent (via
  `actions/github-script` or the `gh` CLI). Stable title ⇒ update, not spam.
- Body includes: which challenge / language / step failed, the mismatch, and the tail of the captured
  process log, pulled from the uploaded Robot `output.xml` / `log.html` artifacts.
- Optionally auto-closes the issue when a later run goes green.

All Robot artifacts (`output.xml`, `log.html`, `report.html`) are uploaded per job with
`actions/upload-artifact` for post-mortem inspection regardless of pass/fail.

---

## 9. Running locally & reuse

Documented in `tools/track-tester/README.md`:

```bash
# one-time
dapr init
# run a single challenge for one language
cd tools/track-tester
uv run robot --include python ../../dapr-101/4-service-invocation-api/tests/challenge.robot
# run the doc-sync check
uv run python docsync/check_doc_sync.py \
  ../../dapr-101/4-service-invocation-api/assignment.md \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot
```

Because the shared keywords in `resources/` are track-agnostic, onboarding another track later is:
add `.robot` suites next to that track's assignments (+ any track-specific keywords) and a sibling
GitHub Actions workflow — no changes to the shared harness.

---

## 10. Component summary

| Component | Responsibility | Depends on |
| --- | --- | --- |
| `resources/dapr.resource` | Track-agnostic keywords for Dapr process lifecycle & assertions | Robot `Process`, `OperatingSystem` |
| `resources/setup.resource` | Env-bootstrap keywords | `ci/setup-dapr-101.sh` |
| `variables/<lang>.yaml` | Per-language dir/build/run values (drift-prone bits, one place) | — |
| `dapr-101/*/tests/challenge.robot` | Per-challenge declarative test flow | `resources/`, `variables/` |
| `docsync/check_doc_sync.py` | Assert assignment commands are covered by suites | markdown + `.robot` files |
| `ci/setup-dapr-101.sh` | Reproduce the sandbox env in CI by wrapping real `_setup` scripts | `_setup/*.sh` |
| `.github/workflows/test-dapr-101.yml` | Orchestrate docsync + agnostic + language-matrix + report jobs | all of the above |

---

## 11. Open questions / future enhancements

- **Instruqt-native layer** (`instruqt track test`) for highest-fidelity validation against the real
  sandbox and `check.sh`/`solve.sh` — deferred; would need an Instruqt API token and check scripts for
  challenges 3–5.
- **Reuse across tracks** — dapr-workflow, dapr-agents, catalyst-101, etc. The harness is built for it;
  each track ships its own suites and workflow when adopted.
- **Auto-close on green** for the drift issue — nice-to-have in the `report` job.
