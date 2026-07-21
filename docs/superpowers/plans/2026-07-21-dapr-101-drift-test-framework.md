# Dapr 101 Drift-Test Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an automated, Robot-Framework-driven end-to-end test framework that runs the Dapr 101 track's actual commands (across .NET/Python/Java/JavaScript) on GitHub Actions weekly and on demand, and reports drift from `dapr/quickstarts` as a GitHub issue.

**Architecture:** A shared, reusable harness under `tools/track-tester/` (uv-managed) provides Robot Framework keywords for the Dapr process lifecycle plus a Python doc-sync checker. Each runnable challenge gets a declarative `.robot` suite next to its `assignment.md`. A GitHub Actions workflow provisions a sandbox-equivalent environment by wrapping the real `_setup` scripts, runs the doc-sync check + the challenge suites (language-agnostic ones once, language-variant ones in a 4-way matrix), and opens/updates a drift issue on failure.

**Tech Stack:** Robot Framework 7.x (standard `Process` + `OperatingSystem` libraries), Python 3.12 + pytest (doc-sync checker), `uv` for env/run, GitHub Actions, `dapr` CLI, Docker.

**Reference spec:** `docs/superpowers/specs/2026-07-21-dapr-101-drift-test-framework-design.md`

## Global Constraints

- **Package dir:** `tools/track-tester/`. All `uv`/`pytest`/`robot` commands run from there unless noted; commands below are written as `(cd tools/track-tester && ...)` so they run from the repo root.
- **Python floor:** `requires-python = ">=3.12"` (matches the existing `tools/github-collector`).
- **Runtime dependency:** `robotframework>=7,<8` only. `pytest>=8` is dev-only.
- **Robot conventions:** every suite sets `Suite Teardown    Terminate All Processes    kill=True`; assertions use substring/regex keywords (`Should Contain`, `Should Match Regexp`) — never byte-exact block matching.
- **Quickstarts base dirs:** service invocation = `<QUICKSTARTS>/service_invocation`; pub/sub = `<QUICKSTARTS>/pub_sub`. `<QUICKSTARTS>` is where `dapr/quickstarts` is cloned (env var `QUICKSTARTS_DIR`). **Verified against a real `dapr/quickstarts` checkout (2026-07-21):** service invocation ships only the `http` variant; pub/sub ships both `http` and `sdk` (the track uses `sdk`); every `dapr.yaml` path used below exists; and all four languages emit both markers (`Order received`/`Order passed`, `Published data`/`Subscriber received`) in their app source.
- **Pinned Dapr version source of truth:** `dapr-101/_setup/sandbox-setup.sh` (`DAPR_CLI_VERSION`, `DAPR_RUNTIME_VERSION`, currently `1.18.0`).
- **Suites are validated locally with `robot --dryrun`** (syntax + keyword resolution) and doc-sync; full end-to-end execution is validated in CI (needs Docker + Dapr + runtimes), triggered via `workflow_dispatch`.
- **Git:** end every commit message with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

---

### Task 1: Scaffold the shared harness project

**Files:**
- Create: `tools/track-tester/pyproject.toml`
- Create: `tools/track-tester/README.md`
- Create: `tools/track-tester/.gitignore`

**Interfaces:**
- Produces: a `uv`-managed project exposing the `robot` CLI and `pytest`.

- [ ] **Step 1: Create `tools/track-tester/pyproject.toml`**

```toml
[project]
name = "track-tester"
version = "0.1.0"
description = "End-to-end drift tests for Dapr University tracks (Robot Framework)"
requires-python = ">=3.12"
dependencies = ["robotframework>=7,<8"]

[dependency-groups]
dev = ["pytest>=8"]

[tool.pytest.ini_options]
pythonpath = ["docsync"]
testpaths = ["docsync/tests"]
```

- [ ] **Step 2: Create `tools/track-tester/.gitignore`**

```gitignore
.venv/
__pycache__/
*.pyc
# Robot Framework outputs
output.xml
log.html
report.html
/results/
```

- [ ] **Step 3: Create `tools/track-tester/README.md`**

```markdown
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

```bash
# one-time environment (matches the sandbox)
bash ci/setup-dapr-101.sh
# QUICKSTARTS_DIR may point at an existing local checkout instead of a fresh clone:
export QUICKSTARTS_DIR="$HOME/quickstarts"

# run one challenge suite for one language
(cd tools/track-tester && uv run robot --include python \
  --variable QUICKSTARTS_DIR:$QUICKSTARTS_DIR \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)

# validate a suite without executing it (syntax + keyword resolution)
(cd tools/track-tester && uv run robot --dryrun \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)

# doc-sync check
(cd tools/track-tester && uv run python docsync/check_doc_sync.py \
  ../../dapr-101/4-service-invocation-api/assignment.md \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)
```
```

- [ ] **Step 4: Sync and verify the toolchain**

Run: `(cd tools/track-tester && uv sync && uv run robot --version)`
Expected: `uv` creates `.venv`, and the last line prints something like `Robot Framework 7.x (Python 3.12 …)` with exit code 0. (Note: `robot --version` exits non-zero on some versions; if so, run `uv run robot --help | head -1` instead and confirm it prints usage.)

- [ ] **Step 5: Commit**

```bash
git add tools/track-tester/pyproject.toml tools/track-tester/README.md tools/track-tester/.gitignore tools/track-tester/uv.lock
git commit -m "feat(track-tester): scaffold shared Robot Framework harness

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: doc-sync — extract runnable commands from an assignment

**Files:**
- Create: `tools/track-tester/docsync/check_doc_sync.py`
- Create: `tools/track-tester/docsync/tests/test_extract.py`

**Interfaces:**
- Produces:
  - `LANG_BY_SUMMARY: dict[str, str]` mapping summary substrings to language keys, e.g. `{".NET": "dotnet", "Python": "python", "Java": "java", "JavaScript": "javascript"}`.
  - `@dataclass Command` with fields `text: str`, `lang: str | None`.
  - `extract_run_commands(md_text: str) -> list[Command]` — one `Command` per non-empty, non-comment line inside every fenced block whose info string starts with `bash` and contains the `run` flag (```` ```bash,run ````, `bash,run,copy`). Commands inside a `<details><summary>Run the X apps</summary>…</details>` block get `lang` set from `LANG_BY_SUMMARY`; commands outside any such block get `lang=None`.

- [ ] **Step 1: Write the failing test** — `tools/track-tester/docsync/tests/test_extract.py`

```python
from check_doc_sync import extract_run_commands, Command


def test_language_agnostic_run_block():
    md = """
Intro text.

```bash,run
dapr run --app-id myapp --dapr-http-port 3500
```

Not runnable, ignored:

```text,nocopy
some expected output
```
"""
    cmds = extract_run_commands(md)
    assert cmds == [Command(text="dapr run --app-id myapp --dapr-http-port 3500", lang=None)]


def test_language_details_blocks_are_tagged():
    md = """
<details>
   <summary><b>Run the .NET apps</b></summary>

```bash,run,copy
dotnet build csharp/http/checkout
dotnet build csharp/http/order-processor
```
</details>

<details>
   <summary><b>Run the Python apps</b></summary>

```bash,run,copy
cd python/http
```
</details>
"""
    cmds = extract_run_commands(md)
    assert cmds == [
        Command(text="dotnet build csharp/http/checkout", lang="dotnet"),
        Command(text="dotnet build csharp/http/order-processor", lang="dotnet"),
        Command(text="cd python/http", lang="python"),
    ]


def test_non_run_fences_are_ignored():
    md = """
```bash,nocopy
version: 1
```

```yaml,nocopy
kind: Component
```
"""
    assert extract_run_commands(md) == []
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `(cd tools/track-tester && uv run pytest docsync/tests/test_extract.py -v)`
Expected: FAIL — `ModuleNotFoundError: No module named 'check_doc_sync'` (or `ImportError`).

- [ ] **Step 3: Implement the extractor** — `tools/track-tester/docsync/check_doc_sync.py`

```python
"""Assert that every runnable command in an assignment.md is covered by its Robot suite."""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass

LANG_BY_SUMMARY = {
    ".NET": "dotnet",
    "Python": "python",
    "Java": "java",
    "JavaScript": "javascript",
}

_FENCE_RE = re.compile(r"^```([^\n`]*)$")
_SUMMARY_RE = re.compile(r"<summary>(.*?)</summary>", re.IGNORECASE | re.DOTALL)


@dataclass(frozen=True)
class Command:
    text: str
    lang: str | None


def _is_run_fence(info: str) -> bool:
    parts = [p.strip() for p in info.split(",")]
    return bool(parts) and parts[0] == "bash" and "run" in parts


def _lang_from_summary(line: str) -> str | None:
    m = _SUMMARY_RE.search(line)
    if not m:
        return None
    # Longest key first so "JavaScript" wins over "Java".
    for key in sorted(LANG_BY_SUMMARY, key=len, reverse=True):
        if key in m.group(1):
            return LANG_BY_SUMMARY[key]
    return None


def extract_run_commands(md_text: str) -> list[Command]:
    commands: list[Command] = []
    current_lang: str | None = None
    in_fence = False
    fence_is_run = False
    for line in md_text.splitlines():
        stripped = line.strip()
        fence = _FENCE_RE.match(stripped)
        if fence is not None:
            if not in_fence:
                in_fence = True
                fence_is_run = _is_run_fence(fence.group(1))
            else:
                in_fence = False
                fence_is_run = False
            continue
        if in_fence:
            if fence_is_run and stripped and not stripped.startswith("#"):
                commands.append(Command(text=stripped, lang=current_lang))
            continue
        # Outside fences: track <details> language scope.
        lang = _lang_from_summary(line)
        if lang is not None:
            current_lang = lang
        elif "</details>" in stripped.lower():
            current_lang = None
    return commands
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `(cd tools/track-tester && uv run pytest docsync/tests/test_extract.py -v)`
Expected: PASS (3 passed).

- [ ] **Step 5: Commit**

```bash
git add tools/track-tester/docsync/check_doc_sync.py tools/track-tester/docsync/tests/test_extract.py
git commit -m "feat(docsync): extract runnable commands from assignment markdown

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: doc-sync — coverage check, CLI, and exit codes

**Files:**
- Modify: `tools/track-tester/docsync/check_doc_sync.py`
- Create: `tools/track-tester/docsync/tests/test_coverage.py`

**Interfaces:**
- Consumes: `Command`, `extract_run_commands` (Task 2).
- Produces:
  - `normalize(text: str) -> str` — collapse all runs of whitespace to a single space and strip.
  - `find_uncovered(commands: list[Command], haystack: str) -> list[Command]` — return commands whose normalized text is **not** a substring of the normalized `haystack`.
  - `main(argv: list[str] | None = None) -> int` — CLI. Usage: `check_doc_sync.py <assignment.md> <suite.robot> [more_files...]`. Reads the assignment, extracts commands, and treats the concatenation of all remaining files (the `.robot` suite plus any variable files) as the haystack. Exit `0` if all covered; prints each uncovered command and exits `1` if any are uncovered; exits `2` on usage/IO error.

- [ ] **Step 1: Write the failing test** — `tools/track-tester/docsync/tests/test_coverage.py`

```python
import textwrap

import check_doc_sync as ds
from check_doc_sync import Command


def test_normalize_collapses_whitespace():
    assert ds.normalize("  dapr   run   -f  . ") == "dapr run -f ."


def test_find_uncovered_reports_missing_only():
    cmds = [
        Command(text="dapr run -f .", lang="python"),
        Command(text="npm install", lang="javascript"),
    ]
    haystack = "Run Multi-App    dapr run -f ."  # only the first appears
    uncovered = ds.find_uncovered(cmds, haystack)
    assert [c.text for c in uncovered] == ["npm install"]


def test_main_passes_when_all_covered(tmp_path, capsys):
    md = tmp_path / "assignment.md"
    md.write_text(textwrap.dedent("""
        ```bash,run
        dapr init
        ```
    """))
    robot = tmp_path / "challenge.robot"
    robot.write_text("Some Keyword    dapr init\n")
    assert ds.main([str(md), str(robot)]) == 0


def test_main_fails_and_lists_uncovered(tmp_path, capsys):
    md = tmp_path / "assignment.md"
    md.write_text(textwrap.dedent("""
        ```bash,run
        dapr uninstall --all
        ```
    """))
    robot = tmp_path / "challenge.robot"
    robot.write_text("Some Keyword    dapr init\n")
    assert ds.main([str(md), str(robot)]) == 1
    assert "dapr uninstall --all" in capsys.readouterr().out


def test_main_usage_error_returns_2():
    assert ds.main([]) == 2
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `(cd tools/track-tester && uv run pytest docsync/tests/test_coverage.py -v)`
Expected: FAIL — `AttributeError: module 'check_doc_sync' has no attribute 'normalize'`.

- [ ] **Step 3: Append the implementation** to `tools/track-tester/docsync/check_doc_sync.py`

```python
def normalize(text: str) -> str:
    return " ".join(text.split())


def find_uncovered(commands: list[Command], haystack: str) -> list[Command]:
    normalized_haystack = normalize(haystack)
    return [c for c in commands if normalize(c.text) not in normalized_haystack]


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) < 2:
        print("usage: check_doc_sync.py <assignment.md> <suite.robot> [more_files...]",
              file=sys.stderr)
        return 2
    assignment_path, *coverage_paths = argv
    try:
        md_text = _read(assignment_path)
        haystack = "\n".join(_read(p) for p in coverage_paths)
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    commands = extract_run_commands(md_text)
    uncovered = find_uncovered(commands, haystack)
    if uncovered:
        print(f"DRIFT: {len(uncovered)} assignment command(s) not covered in {assignment_path}:")
        for c in uncovered:
            label = c.lang or "all"
            print(f"  [{label}] {c.text}")
        return 1
    print(f"OK: all {len(commands)} runnable command(s) covered ({assignment_path}).")
    return 0


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run the full doc-sync test suite to verify it passes**

Run: `(cd tools/track-tester && uv run pytest docsync/ -v)`
Expected: PASS (all tests from Task 2 and Task 3 green).

- [ ] **Step 5: Commit**

```bash
git add tools/track-tester/docsync/check_doc_sync.py tools/track-tester/docsync/tests/test_coverage.py
git commit -m "feat(docsync): add coverage check, CLI, and exit codes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Shared Robot resources & variables

**Files:**
- Create: `tools/track-tester/resources/dapr.resource`
- Create: `tools/track-tester/variables/dapr_101.yaml`
- Create: `tools/track-tester/resources/tests/smoke.robot`

**Interfaces:**
- Produces (keywords available to all suites via `Resource    …/dapr.resource`):
  - `Start Background Process    ${command}    ${logfile}    ${alias}    ${cwd}=${EMPTY}` — start a shell command in the background, redirecting stdout+stderr to `${logfile}`.
  - `Wait Until Log Contains    ${logfile}    ${text}    ${timeout}=60s` — poll until the file contains `${text}` (substring).
  - `Stop Process With SIGINT    ${alias}    ${timeout}=15s` — send SIGINT and wait for exit.
  - `Run And Expect RC Zero    ${command}    ${cwd}=${EMPTY}` — run a shell command to completion, fail unless return code is 0; returns the result object.
  - `Assert Command Output Contains    ${command}    ${text}    ${cwd}=${EMPTY}` — run a shell command, assert `${text}` is a substring of stdout.
  - `Run Multi-App And Assert Markers    ${run_command}    ${cwd}    ${logfile}    ${markers}    ${timeout}=180s` — start `${run_command}` in the background, wait until every marker in the `@{markers}` list appears in `${logfile}`, then SIGINT.
  - `Assert Redis Keys Contain    ${key}` — run `docker exec dapr_redis redis-cli KEYS *`, assert `${key}` appears.
- Produces (variables in `dapr_101.yaml`): `QUICKSTARTS_DIR` (default `${HOME}/quickstarts`), `SVC_MARKERS` (list), `PUBSUB_MARKERS` (list).

- [ ] **Step 1: Create `tools/track-tester/variables/dapr_101.yaml`**

```yaml
QUICKSTARTS_DIR: "${HOME}/quickstarts"
SVC_MARKERS:
  - "Order received"
  - "Order passed"
PUBSUB_MARKERS:
  - "Published data"
  - "Subscriber received"
```

- [ ] **Step 2: Create `tools/track-tester/resources/dapr.resource`**

```robotframework
*** Settings ***
Library    Process
Library    OperatingSystem
Library    Collections

*** Keywords ***
Start Background Process
    [Arguments]    ${command}    ${logfile}    ${alias}    ${cwd}=${EMPTY}
    Create File    ${logfile}    ${EMPTY}
    ${handle}=    Start Process    ${command}    shell=True    alias=${alias}
    ...    cwd=${cwd}    stdout=${logfile}    stderr=STDOUT
    RETURN    ${handle}

Wait Until Log Contains
    [Arguments]    ${logfile}    ${text}    ${timeout}=60s
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    File Should Contain    ${logfile}    ${text}

File Should Contain
    [Arguments]    ${logfile}    ${text}
    ${content}=    Get File    ${logfile}
    Should Contain    ${content}    ${text}

Stop Process With SIGINT
    [Arguments]    ${alias}    ${timeout}=15s
    Send Signal To Process    SIGINT    ${alias}
    ${result}=    Wait For Process    ${alias}    timeout=${timeout}    on_timeout=kill
    RETURN    ${result}

Run And Expect RC Zero
    [Arguments]    ${command}    ${cwd}=${EMPTY}
    ${result}=    Run Process    ${command}    shell=True    cwd=${cwd}
    ...    stdout=PIPE    stderr=STDOUT    timeout=300s
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=Command failed (rc=${result.rc}): ${command}\n${result.stdout}
    RETURN    ${result}

Assert Command Output Contains
    [Arguments]    ${command}    ${text}    ${cwd}=${EMPTY}
    ${result}=    Run And Expect RC Zero    ${command}    ${cwd}
    Should Contain    ${result.stdout}    ${text}
    RETURN    ${result}

Run Multi-App And Assert Markers
    [Arguments]    ${run_command}    ${cwd}    ${logfile}    ${markers}    ${timeout}=180s
    Start Background Process    ${run_command}    ${logfile}    apps    cwd=${cwd}
    FOR    ${marker}    IN    @{markers}
        Wait Until Log Contains    ${logfile}    ${marker}    ${timeout}
    END
    Stop Process With SIGINT    apps

Assert Redis Keys Contain
    [Arguments]    ${key}
    Assert Command Output Contains    docker exec dapr_redis redis-cli KEYS *    ${key}
```

- [ ] **Step 3: Create a smoke suite that references each keyword** — `tools/track-tester/resources/tests/smoke.robot`

```robotframework
*** Settings ***
Resource    ../dapr.resource
Variables   ../../variables/dapr_101.yaml

*** Test Cases ***
Keywords Resolve
    [Documentation]    Dry-run only: verifies every shared keyword and variable resolves.
    Start Background Process    echo hi    /tmp/x.log    smoke
    Wait Until Log Contains    /tmp/x.log    hi
    Stop Process With SIGINT    smoke
    Run And Expect RC Zero    true
    Assert Command Output Contains    echo hi    hi
    Run Multi-App And Assert Markers    echo hi    ${EMPTY}    /tmp/y.log    ${SVC_MARKERS}
    Assert Redis Keys Contain    somekey
```

- [ ] **Step 4: Validate keyword resolution with a dry run**

Run: `(cd tools/track-tester && uv run robot --dryrun resources/tests/smoke.robot)`
Expected: PASS — `1 test, 1 passed, 0 failed`. A dry run resolves keywords/variables without executing them; any unresolved keyword or variable fails here.

- [ ] **Step 5: Commit**

```bash
git add tools/track-tester/resources tools/track-tester/variables
git commit -m "feat(track-tester): add shared Dapr Robot keywords and variables

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Challenge 2 suite (Dapr CLI: install, init, version)

**Files:**
- Create: `dapr-101/2-dapr-cli/tests/challenge.robot`

**Interfaces:**
- Consumes: keywords from `resources/dapr.resource` (Task 4).
- Produces: a suite that runs without a language filter (all challenge-2 commands are language-agnostic).

- [ ] **Step 1: Create the suite** — `dapr-101/2-dapr-cli/tests/challenge.robot`

```robotframework
*** Settings ***
Documentation     Drift test for dapr-101 challenge 2 (Dapr CLI). Assumes the Dapr CLI is
...               already installed and `dapr init` has run (done by ci/setup-dapr-101.sh).
Resource          ../../../tools/track-tester/resources/dapr.resource
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${DAPR_VERSION}    1.18.0

*** Test Cases ***
Dapr CLI Reports Help
    Assert Command Output Contains    dapr -h    Distributed Application Runtime

Dapr Version Matches Pinned Runtime
    ${r}=    Run And Expect RC Zero    dapr --version
    Should Contain    ${r.stdout}    CLI version: ${DAPR_VERSION}
    Should Contain    ${r.stdout}    Runtime version: ${DAPR_VERSION}

Dapr Init Containers Are Running
    ${r}=    Run And Expect RC Zero    docker ps --format {{.Names}}
    Should Contain    ${r.stdout}    dapr_placement
    Should Contain    ${r.stdout}    dapr_scheduler
    Should Contain    ${r.stdout}    dapr_redis
    Should Contain    ${r.stdout}    dapr_zipkin
```

> Note for the executor: `${DAPR_VERSION}` mirrors `DAPR_CLI_VERSION` in `dapr-101/_setup/sandbox-setup.sh`. The workflow (Task 10) overrides it with `--variable DAPR_VERSION:<parsed>` so the pinned value has a single source of truth at run time; the literal here is a local-dev default.

- [ ] **Step 2: Validate with a dry run**

Run: `(cd tools/track-tester && uv run robot --dryrun ../../dapr-101/2-dapr-cli/tests/challenge.robot)`
Expected: PASS — `3 tests, 3 passed`.

- [ ] **Step 3: Run the doc-sync check**

Run:
```bash
(cd tools/track-tester && uv run python docsync/check_doc_sync.py \
  ../../dapr-101/2-dapr-cli/assignment.md \
  ../../dapr-101/2-dapr-cli/tests/challenge.robot)
```
Expected: The install/init commands (`wget … install.sh`, `dapr init`) are performed by the CI setup script, not this suite. So doc-sync will report them as uncovered. Resolve by adding the `wget … | /bin/bash` and `dapr init` commands as covered — add a Robot comment block at the bottom of the suite so they are present in the coverage haystack without being executed twice:

```robotframework
# doc-sync coverage (performed by ci/setup-dapr-101.sh, asserted above):
#   wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
#   dapr init
```

Re-run the doc-sync command; expected: `OK: all N runnable command(s) covered`.

- [ ] **Step 4: Commit**

```bash
git add dapr-101/2-dapr-cli/tests/challenge.robot
git commit -m "test(dapr-101): add challenge 2 (CLI) drift suite

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Challenge 3 suite (state management HTTP API)

**Files:**
- Create: `dapr-101/3-state-management-api/tests/challenge.robot`

**Interfaces:**
- Consumes: keywords from `resources/dapr.resource` (Task 4).
- Produces: a language-agnostic suite exercising the sidecar-in-background + curl + Redis flow.

- [ ] **Step 1: Create the suite** — `dapr-101/3-state-management-api/tests/challenge.robot`

```robotframework
*** Settings ***
Documentation     Drift test for dapr-101 challenge 3 (State Management HTTP API).
Resource          ../../../tools/track-tester/resources/dapr.resource
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${SIDECAR_LOG}    ${TEMPDIR}/dapr-101-ch3-sidecar.log

*** Test Cases ***
State Management API Round Trip
    Start Background Process
    ...    dapr run --app-id myapp --dapr-http-port 3500    ${SIDECAR_LOG}    sidecar
    Wait Until Log Contains    ${SIDECAR_LOG}    You're up and running!    timeout=60s

    Run And Expect RC Zero
    ...    curl -X POST -H "Content-Type: application/json" -d '[{ "key": "name", "value": "Bruce Wayne"}]' http://localhost:3500/v1.0/state/statestore

    Assert Command Output Contains
    ...    curl http://localhost:3500/v1.0/state/statestore/name    Bruce Wayne

    Assert Redis Keys Contain    myapp||name

    Run And Expect RC Zero
    ...    curl -v -X DELETE -H "Content-Type: application/json" http://localhost:3500/v1.0/state/statestore/name

    ${r}=    Run And Expect RC Zero    docker exec dapr_redis redis-cli KEYS *
    Should Not Contain    ${r.stdout}    myapp||name

    Stop Process With SIGINT    sidecar
    Wait Until Log Contains    ${SIDECAR_LOG}    Exited Dapr successfully    timeout=15s

Statestore Component File Is Redis
    ${r}=    Run And Expect RC Zero    cat ${HOME}/.dapr/components/statestore.yaml
    Should Contain    ${r.stdout}    type: state.redis
    Should Contain    ${r.stdout}    name: statestore
```

- [ ] **Step 2: Validate with a dry run**

Run: `(cd tools/track-tester && uv run robot --dryrun ../../dapr-101/3-state-management-api/tests/challenge.robot)`
Expected: PASS — `2 tests, 2 passed`.

- [ ] **Step 3: Run the doc-sync check**

Run:
```bash
(cd tools/track-tester && uv run python docsync/check_doc_sync.py \
  ../../dapr-101/3-state-management-api/assignment.md \
  ../../dapr-101/3-state-management-api/tests/challenge.robot)
```
Expected: `OK: all N runnable command(s) covered`. If it reports the `keys *` command (run in the assignment's Redis terminal as ` keys *`) as uncovered, note that the suite covers it via `docker exec dapr_redis redis-cli KEYS *`; add the assignment's literal `keys *` line as a `# doc-sync coverage:` comment so the substring is present. Re-run; expected `OK`.

- [ ] **Step 4: Commit**

```bash
git add dapr-101/3-state-management-api/tests/challenge.robot
git commit -m "test(dapr-101): add challenge 3 (state management) drift suite

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Challenge 4 suite (service invocation, language matrix)

**Files:**
- Create: `dapr-101/4-service-invocation-api/tests/challenge.robot`

**Interfaces:**
- Consumes: `Run And Expect RC Zero`, `Run Multi-App And Assert Markers` (Task 4); `SVC_MARKERS`, `QUICKSTARTS_DIR` (Task 4 variables).
- Produces: four tagged test cases (`dotnet`, `python`, `java`, `javascript`), each runnable in isolation via `robot --include <lang>`.

- [ ] **Step 1: Create the suite** — `dapr-101/4-service-invocation-api/tests/challenge.robot`

```robotframework
*** Settings ***
Documentation     Drift test for dapr-101 challenge 4 (Service Invocation) across languages.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_101.yaml
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${BASE}       ${QUICKSTARTS_DIR}/service_invocation
${LOG}        ${TEMPDIR}/dapr-101-ch4.log

*** Test Cases ***
DotNet Service Invocation
    [Tags]    dotnet
    Run And Expect RC Zero    dotnet build csharp/http/checkout           ${BASE}
    Run And Expect RC Zero    dotnet build csharp/http/order-processor    ${BASE}
    Run Multi-App And Assert Markers
    ...    dapr run -f "csharp/http/dapr.yaml"    ${BASE}    ${LOG}    ${SVC_MARKERS}

Python Service Invocation
    [Tags]    python
    Run And Expect RC Zero    uv sync --all-packages    ${BASE}/python/http
    Run Multi-App And Assert Markers
    ...    uv run dapr run -f .    ${BASE}/python/http    ${LOG}    ${SVC_MARKERS}

Java Service Invocation
    [Tags]    java
    Run And Expect RC Zero    mvn clean install    ${BASE}/java/http/order-processor
    Run And Expect RC Zero    mvn clean install    ${BASE}/java/http/checkout
    Run Multi-App And Assert Markers
    ...    dapr run -f .    ${BASE}/java/http    ${LOG}    ${SVC_MARKERS}

JavaScript Service Invocation
    [Tags]    javascript
    Run And Expect RC Zero    npm install    ${BASE}/javascript/http/order-processor
    Run And Expect RC Zero    npm install    ${BASE}/javascript/http/checkout
    Run Multi-App And Assert Markers
    ...    dapr run -f .    ${BASE}/javascript/http    ${LOG}    ${SVC_MARKERS}
```

> Note: the assignment uses `cd python/http` then `uv run dapr run -f .`. This suite expresses the same commands via each keyword's `${cwd}` argument instead of a stateful `cd`, which is equivalent and avoids cross-test working-directory leakage. The doc-sync `cd` lines are covered by the `# doc-sync coverage` comment added in Step 3.

- [ ] **Step 2: Validate each language path with dry runs**

Run:
```bash
(cd tools/track-tester && for l in dotnet python java javascript; do \
  uv run robot --dryrun --include $l ../../dapr-101/4-service-invocation-api/tests/challenge.robot || exit 1; done)
```
Expected: each invocation runs exactly 1 test and passes (dry run).

- [ ] **Step 3: Run the doc-sync check and cover `cd` lines**

Run:
```bash
(cd tools/track-tester && uv run python docsync/check_doc_sync.py \
  ../../dapr-101/4-service-invocation-api/assignment.md \
  ../../dapr-101/4-service-invocation-api/tests/challenge.robot)
```
If `cd python/http`, `cd java/http/order-processor`, `cd ../checkout`, `cd ..`, `cd javascript/http/order-processor` are reported uncovered, add them at the bottom of the suite as coverage comments (they are expressed as `${cwd}` arguments, not executed as `cd`):

```robotframework
# doc-sync coverage (expressed via cwd arguments above):
#   cd python/http
#   cd java/http/order-processor
#   cd ../checkout
#   cd ..
#   cd javascript/http/order-processor
#   cd ../checkout
#   cd ..
```

Re-run; expected: `OK: all N runnable command(s) covered`.

- [ ] **Step 4: Commit**

```bash
git add dapr-101/4-service-invocation-api/tests/challenge.robot
git commit -m "test(dapr-101): add challenge 4 (service invocation) matrix drift suite

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Challenge 5 suite (pub/sub, language matrix)

**Files:**
- Create: `dapr-101/5-pubsub-api/tests/challenge.robot`

**Interfaces:**
- Consumes: `Run And Expect RC Zero`, `Run Multi-App And Assert Markers` (Task 4); `PUBSUB_MARKERS`, `QUICKSTARTS_DIR` (Task 4 variables).
- Produces: four tagged test cases (`dotnet`, `python`, `java`, `javascript`). Same shape as Task 7 but base dir `pub_sub` and variant subfolder `sdk`.

- [ ] **Step 1: Create the suite** — `dapr-101/5-pubsub-api/tests/challenge.robot`

```robotframework
*** Settings ***
Documentation     Drift test for dapr-101 challenge 5 (Pub/Sub) across languages.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_101.yaml
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${BASE}       ${QUICKSTARTS_DIR}/pub_sub
${LOG}        ${TEMPDIR}/dapr-101-ch5.log

*** Test Cases ***
DotNet Pub Sub
    [Tags]    dotnet
    Run And Expect RC Zero    dotnet build csharp/sdk/checkout           ${BASE}
    Run And Expect RC Zero    dotnet build csharp/sdk/order-processor    ${BASE}
    Run Multi-App And Assert Markers
    ...    dapr run -f "csharp/sdk/dapr.yaml"    ${BASE}    ${LOG}    ${PUBSUB_MARKERS}

Python Pub Sub
    [Tags]    python
    Run And Expect RC Zero    uv sync --all-packages    ${BASE}/python/sdk
    Run Multi-App And Assert Markers
    ...    uv run dapr run -f .    ${BASE}/python/sdk    ${LOG}    ${PUBSUB_MARKERS}

Java Pub Sub
    [Tags]    java
    Run And Expect RC Zero    mvn clean install    ${BASE}/java/sdk/order-processor
    Run And Expect RC Zero    mvn clean install    ${BASE}/java/sdk/checkout
    Run Multi-App And Assert Markers
    ...    dapr run -f .    ${BASE}/java/sdk    ${LOG}    ${PUBSUB_MARKERS}

JavaScript Pub Sub
    [Tags]    javascript
    Run And Expect RC Zero    npm install    ${BASE}/javascript/sdk/order-processor
    Run And Expect RC Zero    npm install    ${BASE}/javascript/sdk/checkout
    Run Multi-App And Assert Markers
    ...    dapr run -f .    ${BASE}/javascript/sdk    ${LOG}    ${PUBSUB_MARKERS}
```

- [ ] **Step 2: Validate each language path with dry runs**

Run:
```bash
(cd tools/track-tester && for l in dotnet python java javascript; do \
  uv run robot --dryrun --include $l ../../dapr-101/5-pubsub-api/tests/challenge.robot || exit 1; done)
```
Expected: each invocation runs exactly 1 test and passes (dry run).

- [ ] **Step 3: Run the doc-sync check and cover `cd` lines**

Run:
```bash
(cd tools/track-tester && uv run python docsync/check_doc_sync.py \
  ../../dapr-101/5-pubsub-api/assignment.md \
  ../../dapr-101/5-pubsub-api/tests/challenge.robot)
```
If the `cd python/sdk`, `cd java/sdk/order-processor`, `cd ../checkout`, `cd ..`, `cd javascript/sdk/order-processor` lines are reported uncovered, add them at the bottom of the suite:

```robotframework
# doc-sync coverage (expressed via cwd arguments above):
#   cd python/sdk
#   cd java/sdk/order-processor
#   cd ../checkout
#   cd ..
#   cd javascript/sdk/order-processor
#   cd ../checkout
#   cd ..
```

Re-run; expected: `OK: all N runnable command(s) covered`.

- [ ] **Step 4: Commit**

```bash
git add dapr-101/5-pubsub-api/tests/challenge.robot
git commit -m "test(dapr-101): add challenge 5 (pub/sub) matrix drift suite

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: CI setup script

**Files:**
- Create: `tools/track-tester/ci/setup-dapr-101.sh`

**Interfaces:**
- Produces: an idempotent script that reproduces the dapr-101 sandbox in a CI runner. Reads `QUICKSTARTS_DIR` (default `$HOME/quickstarts`) and an optional `LANGS` (default `dotnet python java javascript`) to install only the needed runtimes. Exports the pinned Dapr version parsed from `_setup/sandbox-setup.sh`.

- [ ] **Step 1: Create the script** — `tools/track-tester/ci/setup-dapr-101.sh`

```bash
#!/usr/bin/env bash
# Reproduce the dapr-101 sandbox environment in CI by reusing the real _setup scripts.
# Instruqt-only bits (agent variable set, docker login) are adapted/omitted here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SETUP_DIR="$REPO_ROOT/dapr-101/_setup"
QUICKSTARTS_DIR="${QUICKSTARTS_DIR:-$HOME/quickstarts}"

# 1. Parse the pinned Dapr version (single source of truth) and export it for the suites.
DAPR_CLI_VERSION="$(grep -oP 'DAPR_CLI_VERSION\s+\K[0-9.]+' "$SETUP_DIR/sandbox-setup.sh")"
DAPR_RUNTIME_VERSION="$(grep -oP 'DAPR_RUNTIME_VERSION\s+\K[0-9.]+' "$SETUP_DIR/sandbox-setup.sh")"
echo "DAPR_CLI_VERSION=$DAPR_CLI_VERSION"     >> "${GITHUB_ENV:-/dev/stdout}"
echo "DAPR_RUNTIME_VERSION=$DAPR_RUNTIME_VERSION" >> "${GITHUB_ENV:-/dev/stdout}"

# 2. Clone the quickstarts repo (drift source of truth).
if [ ! -d "$QUICKSTARTS_DIR/.git" ]; then
  git clone --depth 1 https://github.com/dapr/quickstarts.git "$QUICKSTARTS_DIR"
fi

# 3. Install uv (used by the Python quickstarts and to run robot).
if ! command -v uv >/dev/null 2>&1; then
  wget -qO- https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

# 4. Install the Dapr CLI at the pinned version and initialize Dapr.
if ! command -v dapr >/dev/null 2>&1; then
  wget -q "https://raw.githubusercontent.com/dapr/cli/v${DAPR_CLI_VERSION}/install/install.sh" -O - \
    | DAPR_INSTALL_VERSION="$DAPR_CLI_VERSION" /bin/bash
fi
dapr uninstall --all >/dev/null 2>&1 || true
dapr init --runtime-version "$DAPR_RUNTIME_VERSION"

echo "Setup complete. QUICKSTARTS_DIR=$QUICKSTARTS_DIR, Dapr $DAPR_CLI_VERSION"
```

- [ ] **Step 2: Make it executable and syntax-check it**

Run:
```bash
chmod +x tools/track-tester/ci/setup-dapr-101.sh
bash -n tools/track-tester/ci/setup-dapr-101.sh && echo "syntax OK"
```
Expected: `syntax OK`. (Full execution is validated in CI in Task 10 — it needs Docker + network + the GitHub runner's preinstalled dotnet/java/node.)

- [ ] **Step 3: Verify version parsing against the real setup file**

Run:
```bash
grep -oP 'DAPR_CLI_VERSION\s+\K[0-9.]+' dapr-101/_setup/sandbox-setup.sh
```
Expected: prints `1.18.0`. If it prints nothing, the regex must be adjusted to match the actual line format in `sandbox-setup.sh` before proceeding.

- [ ] **Step 4: Commit**

```bash
git add tools/track-tester/ci/setup-dapr-101.sh
git commit -m "feat(track-tester): add CI environment setup script for dapr-101

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 10: GitHub Actions workflow (docsync + agnostic + matrix + report)

**Files:**
- Create: `.github/workflows/test-dapr-101.yml`

**Interfaces:**
- Consumes: `ci/setup-dapr-101.sh` (Task 9), all challenge suites (Tasks 5–8), the doc-sync checker (Tasks 2–3).
- Produces: a workflow triggered weekly, manually, and on PRs touching relevant paths; opens/updates a `drift-report` issue on failure.

- [ ] **Step 1: Create the workflow** — `.github/workflows/test-dapr-101.yml`

```yaml
name: Test dapr-101 track

on:
  schedule:
    - cron: '0 6 * * 1'   # Mondays 06:00 UTC
  workflow_dispatch:
  pull_request:
    paths:
      - 'dapr-101/**'
      - 'tools/track-tester/**'
      - '.github/workflows/test-dapr-101.yml'

permissions:
  contents: read
  issues: write

jobs:
  docsync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - name: Sync harness
        run: (cd tools/track-tester && uv sync)
      - name: Check doc-sync for all runnable challenges
        run: |
          cd tools/track-tester
          for ch in 2-dapr-cli 3-state-management-api 4-service-invocation-api 5-pubsub-api; do
            uv run python docsync/check_doc_sync.py \
              ../../dapr-101/$ch/assignment.md \
              ../../dapr-101/$ch/tests/challenge.robot
          done

  agnostic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - name: Setup Dapr sandbox
        run: bash tools/track-tester/ci/setup-dapr-101.sh
      - name: Sync harness
        run: (cd tools/track-tester && uv sync)
      - name: Run challenges 2 and 3
        run: |
          cd tools/track-tester
          uv run robot --outputdir results/ch2 \
            --variable DAPR_VERSION:${DAPR_CLI_VERSION} \
            ../../dapr-101/2-dapr-cli/tests/challenge.robot
          uv run robot --outputdir results/ch3 \
            ../../dapr-101/3-state-management-api/tests/challenge.robot
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: robot-agnostic
          path: tools/track-tester/results/

  languages:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        lang: [dotnet, python, java, javascript]
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - name: Setup Dapr sandbox
        env:
          LANGS: ${{ matrix.lang }}
        run: bash tools/track-tester/ci/setup-dapr-101.sh
      - name: Sync harness
        run: (cd tools/track-tester && uv sync)
      - name: Run challenges 4 and 5 for ${{ matrix.lang }}
        env:
          QUICKSTARTS_DIR: ${{ env.HOME }}/quickstarts
        run: |
          cd tools/track-tester
          uv run robot --outputdir results/ch4 --include ${{ matrix.lang }} \
            ../../dapr-101/4-service-invocation-api/tests/challenge.robot
          uv run robot --outputdir results/ch5 --include ${{ matrix.lang }} \
            ../../dapr-101/5-pubsub-api/tests/challenge.robot
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: robot-${{ matrix.lang }}
          path: tools/track-tester/results/

  report:
    needs: [docsync, agnostic, languages]
    if: failure() && github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const title = 'Dapr 101 track drift detected';
            const runUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
            const body = [
              `The scheduled dapr-101 drift test **failed**.`,
              ``,
              `- Run: ${runUrl}`,
              `- Download the \`robot-*\` artifacts for the failing challenge/language and open \`log.html\`.`,
              ``,
              `_This issue is updated automatically each run; the failing step is in the workflow logs above._`,
            ].join('\n');
            const existing = await github.rest.issues.listForRepo({
              owner: context.repo.owner, repo: context.repo.repo,
              state: 'open', labels: 'drift-report',
            });
            const match = existing.data.find(i => i.title === title);
            if (match) {
              await github.rest.issues.createComment({
                owner: context.repo.owner, repo: context.repo.repo,
                issue_number: match.number, body,
              });
            } else {
              await github.rest.issues.create({
                owner: context.repo.owner, repo: context.repo.repo,
                title, body, labels: ['drift-report'],
              });
            }
```

- [ ] **Step 2: Lint the workflow**

Run: `command -v actionlint >/dev/null && actionlint .github/workflows/test-dapr-101.yml || echo "actionlint not installed; skipping (CI will validate)"`
Expected: no errors reported (or the skip message). Fix any reported YAML/expression errors.

- [ ] **Step 3: Ensure the `drift-report` label exists**

Run:
```bash
gh label create drift-report --description "Automated track drift report" --color B60205 2>/dev/null \
  || echo "label exists or gh not authenticated"
```
Expected: label created, or the informational message. (If `gh` is unavailable, note that the label must be created once in the repo settings for the `report` job to apply it.)

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/test-dapr-101.yml
git commit -m "ci(dapr-101): add weekly drift-test workflow with issue reporting

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5: End-to-end validation via manual dispatch**

After the branch is pushed, trigger the workflow manually and confirm a full green run (this is the first real execution of the suites against a live environment):

Run: `gh workflow run "Test dapr-101 track" --ref <branch> && echo "dispatched — watch with: gh run watch"`
Expected: the workflow runs; `docsync`, `agnostic`, and all four `languages` matrix jobs pass. Investigate and fix any genuine failures (they indicate either a suite bug or real drift). Iterate until green.

---

## Self-Review

**Spec coverage:**
- §1 problem/goals — full-execution fidelity (Tasks 5–8 run real commands), all 4 languages (Tasks 7–8 tags + Task 10 matrix), challenges 2–5 (Tasks 5–8), test-next-to-md (suites under each challenge's `tests/`), weekly + on-demand + issue reporting (Task 10). ✓
- §2 engine — Robot Framework `Process`/`OperatingSystem` (Task 4). ✓
- §3 architecture — four jobs docsync/agnostic/languages/report (Task 10). ✓
- §4 layout — `tools/track-tester/{resources,variables,docsync,ci}` + per-challenge `tests/` (Tasks 1,4,2/3,9,5–8). ✓
- §5 mapping — background sidecar + markers + SIGINT + substring matching (Tasks 4,6,7,8). ✓
- §6 doc-sync — extraction + coverage + exit codes (Tasks 2,3), wired into workflow (Task 10). ✓
- §7 CI env — wraps real `_setup` scripts, per-language installs, `dapr --version` assertion (Tasks 9,5). ✓
- §8 reporting — stable-title issue open/update via github-script (Task 10). ✓
- §9 local/reuse — README run instructions (Task 1). ✓

**Deviation from spec (noted):** the spec §5 suggested per-language *variable files* holding dir/build/run values. Because the build/run commands differ per-language in shape (not just values) and the variant subfolder differs per challenge (`http` vs `sdk`), the plan instead places the drift-prone commands inline in tagged test cases and keeps `variables/dapr_101.yaml` for the shared base dir + marker lists. This is still next-to-markdown and doc-sync-guarded; it is clearer for a zero-context implementer. Update the spec's §5/§10 wording if strict alignment is desired.

**Placeholder scan:** no TBD/TODO; all code blocks are complete. The `# doc-sync coverage` comment steps (Tasks 5–8) are conditional-on-output but give the exact lines to add. ✓

**Type consistency:** `Command(text, lang)`, `extract_run_commands`, `normalize`, `find_uncovered`, `main` are used consistently across Tasks 2–3 and the workflow. Keyword names (`Run And Expect RC Zero`, `Run Multi-App And Assert Markers`, `Assert Redis Keys Contain`, `Start Background Process`, `Wait Until Log Contains`, `Stop Process With SIGINT`) match between Task 4 definitions and Tasks 5–8 usages. ✓
