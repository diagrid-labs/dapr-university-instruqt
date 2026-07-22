# dapr-workflow Drift Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Robot Framework drift tests for the 9 runnable `dapr-workflow` challenges (2–10) across .NET, Java, and Python, with full harness parity to `dapr-101` (shared resource + variables + docsync + CI workflow).

**Architecture:** Each challenge gets a `tests/challenge.robot` suite with three tagged tests (`dotnet`/`java`/`python`). Shared workflow keywords live in a new `tools/track-tester/resources/workflow.resource` that imports the existing `dapr.resource`. Shared values (quickstarts base dir, ready-probe helper) live in `tools/track-tester/variables/dapr_workflow.py`. .NET/Python drive apps with `dapr run -f .` and hit the Dapr workflow API; Java uses `mvn spring-boot:test-run` (Testcontainers) and app-owned endpoints on port 8080.

**Tech Stack:** Robot Framework (Process/OperatingSystem/Collections/String libraries), `uv` (runs robot from `tools/track-tester/`), Dapr CLI, Docker, `dapr/quickstarts` (`tutorials/workflow`).

## Global Constraints

- **Working directory for all `robot`/`uv`/docsync commands:** `tools/track-tester/` (i.e. `cd tools/track-tester` first, then use `../../` relative paths). This matches the dapr-101 README.
- **Quickstarts location:** the suites read `QUICKSTARTS_DIR` (env var → falls back to `~/quickstarts`). For local runs: `export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"`.
- **Workflow code base path:** `${QUICKSTARTS_DIR}/tutorials/workflow`.
- **Languages:** `.NET`, `Java`, `Python` only. No JavaScript.
- **Runnable challenges:** 2–10. Challenges 1 and 11 are conceptual — no suites.
- **Robot argument separator:** TWO OR MORE spaces separate a keyword from its arguments (a single space is part of the value).
- **Never modify** the dapr-101 suites, `dapr.resource`, `check_doc_sync.py`, or any `dapr-workflow/**/assignment.md`.
- **Local verification per challenge:** `--dryrun` (all langs) + docsync + a real run with `--include python`. The `dotnet` and `java` tests are verified by CI (Java needs Docker/Testcontainers). If `dotnet`/`java` are available locally, run them too.
- **Port/appID reference (.NET & Python):**

  | Ch | folder (csharp / java / python)                                              | appPort | daprHTTPPort |
  |----|------------------------------------------------------------------------------|---------|--------------|
  | 2  | `fundamentals`                                                               | 5254    | 3554         |
  | 3  | `task-chaining`                                                              | 5255    | 3555         |
  | 4  | `fan-out-fan-in`                                                             | 5256    | 3556         |
  | 5  | `monitor-pattern`                                                           | 5257    | 3557         |
  | 6  | `external-system-interaction` / `external-system-interactions` / `external-system-interaction` | 5258 | 3558 |
  | 7  | `child-workflows`                                                           | 5259    | 3559         |
  | 8  | `resiliency-and-compensation`                                              | 5264    | 3564         |
  | 9  | `combined-patterns` (workflow-app 5260/3560, shipping 5261/3561)           | 5260    | 3560         |
  | 10 | `workflow-management`                                                       | 5262    | 3562         |

  Java always uses port `8080`. Note ch6's Java folder is plural: `external-system-interactions`.

---

## File Structure

- **Create** `tools/track-tester/variables/dapr_workflow.py` — shared variables (Task 1).
- **Create** `tools/track-tester/resources/workflow.resource` — shared workflow keywords (Task 2).
- **Modify** `tools/track-tester/resources/tests/smoke.robot` — add a workflow-keyword resolution check (Task 2).
- **Create** `dapr-workflow/<n>-<name>/tests/challenge.robot` — one per challenge (Tasks 3–11).
- **Create** `tools/track-tester/ci/setup-dapr-workflow.sh` — CI sandbox setup (Task 12).
- **Create** `.github/workflows/test-dapr-workflow.yml` — CI workflow (Task 13).

---

## Task 1: Shared variables file

**Files:**
- Create: `tools/track-tester/variables/dapr_workflow.py`

**Interfaces:**
- Produces: module-level Robot variables `${QUICKSTARTS_DIR}` (str) and `${WF_BASE}` (str, `= <QUICKSTARTS_DIR>/tutorials/workflow`).

- [ ] **Step 1: Write the variables file**

```python
"""Shared variables for the dapr-workflow track suites.

QUICKSTARTS_DIR resolves (in order): the QUICKSTARTS_DIR environment variable if
set (used by CI and by local runs pointing at an existing checkout), otherwise
~/quickstarts expanded to an absolute path (where ci/setup-dapr-workflow.sh
clones the repo).

WF_BASE is the tutorials/workflow subtree, which is where the dapr-workflow
track's per-language pattern folders (csharp/java/python) live.
"""
import os

QUICKSTARTS_DIR = os.environ.get("QUICKSTARTS_DIR") or os.path.expanduser("~/quickstarts")
WF_BASE = os.path.join(QUICKSTARTS_DIR, "tutorials", "workflow")
```

- [ ] **Step 2: Verify the module imports and resolves**

Run:
```bash
cd tools/track-tester
uv run python -c "import importlib.util, os; \
spec=importlib.util.spec_from_file_location('m','variables/dapr_workflow.py'); \
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); \
print(m.WF_BASE)"
```
Expected: prints a path ending in `/tutorials/workflow` (e.g. `/Users/you/quickstarts/tutorials/workflow`).

- [ ] **Step 3: Commit**

```bash
git add tools/track-tester/variables/dapr_workflow.py
git commit -m "test(dapr-workflow): add shared variables file"
```

---

## Task 2: Shared workflow keywords + smoke check

**Files:**
- Create: `tools/track-tester/resources/workflow.resource`
- Modify: `tools/track-tester/resources/tests/smoke.robot`

**Interfaces:**
- Consumes: keywords from `dapr.resource` (`Start Background Process`, `Run And Expect RC Zero`, `Assert Command Output Contains`, `Stop Process With SIGINT`).
- Produces these keywords (used by every challenge suite):
  - `Start Workflow App    ${command}    ${cwd}    ${logfile}    ${probe_url}    ${alias}=app    ${timeout}=120s` — starts the run command in the background under `${alias}`, then blocks until `${probe_url}` responds.
  - `Wait Until App Responds    ${probe_url}    ${timeout}=120s`
  - `Capture Command Output    ${command}    ${cwd}=${EMPTY}` → returns the command's stdout, stripped (used to capture instance IDs).
  - `Wait Until Command Output Contains    ${command}    ${text}    ${timeout}=90s`
  - `Wait Until Workflow Completed    ${status_url}    ${expected_output}=${EMPTY}    ${timeout}=90s` — polls `${status_url}` until it contains `"runtimeStatus":"COMPLETED"`, then (if given) asserts `${expected_output}` is present.

- [ ] **Step 1: Write `workflow.resource`**

```robotframework
# Reusable keywords for the dapr-workflow suites. Imports the generic Dapr
# process/assertion keywords from dapr.resource and adds workflow-specific ones
# (readiness probing, instance-id capture, workflow-status polling).

*** Settings ***
Resource    dapr.resource
# String ships with Robot Framework; used here for Strip String.
Library     String

*** Keywords ***
Wait Until App Responds
    # Readiness probe: curl the app's port until the connection succeeds. A running
    # HTTP server returns *some* response (even 404) => curl exits 0; a refused
    # connection => curl exits 7. This is language-agnostic (works for the .NET,
    # Python and Java apps) and avoids depending on exact framework log lines.
    [Arguments]    ${probe_url}    ${timeout}=120s
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Run And Expect RC Zero    curl -s -o /dev/null ${probe_url}

Start Workflow App
    # Launch the app in the background (non-blocking) and wait until it is ready.
    [Arguments]    ${command}    ${cwd}    ${logfile}    ${probe_url}    ${alias}=app    ${timeout}=120s
    Start Background Process    ${command}    ${logfile}    ${alias}    cwd=${cwd}
    Wait Until App Responds    ${probe_url}    ${timeout}

Capture Command Output
    # Run a command to completion (rc 0 required) and return its stdout, stripped
    # of surrounding whitespace/newlines. Used to capture workflow instance IDs
    # from the assignment's curl+grep+sed pipelines.
    [Arguments]    ${command}    ${cwd}=${EMPTY}
    ${r}=    Run And Expect RC Zero    ${command}    ${cwd}
    ${out}=    Strip String    ${r.stdout}
    RETURN    ${out}

Wait Until Command Output Contains
    # Poll: retry running ${command} until its output contains ${text}.
    [Arguments]    ${command}    ${text}    ${timeout}=90s
    Wait Until Keyword Succeeds    ${timeout}    3s
    ...    Assert Command Output Contains    ${command}    ${text}

Wait Until Workflow Completed
    # Poll the Dapr workflow status endpoint until the instance reports COMPLETED,
    # then (optionally) assert the workflow output contains an expected substring.
    [Arguments]    ${status_url}    ${expected_output}=${EMPTY}    ${timeout}=90s
    Wait Until Command Output Contains    curl -s ${status_url}    "runtimeStatus":"COMPLETED"    ${timeout}
    IF    '${expected_output}' != '${EMPTY}'
        Assert Command Output Contains    curl -s ${status_url}    ${expected_output}
    END
```

- [ ] **Step 2: Add a resolution check to `smoke.robot`**

Append this test case to the end of `tools/track-tester/resources/tests/smoke.robot` (leave the existing content untouched):

```robotframework

Workflow Keywords Resolve
    [Documentation]    Dry-run only: verifies the workflow.resource keywords resolve.
    Wait Until App Responds    http://localhost:1/    1s
    Start Workflow App    echo hi    ${EMPTY}    /tmp/wf.log    http://localhost:1/    wfapp    1s
    Capture Command Output    echo hi
    Wait Until Command Output Contains    echo hi    hi
    Wait Until Workflow Completed    http://localhost:1/    someoutput
```

Also add the import to that file's `*** Settings ***` section (below the existing `Resource`/`Variables` lines):

```robotframework
Resource    ../workflow.resource
```

- [ ] **Step 3: Dry-run the smoke suite to verify all keywords resolve**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun resources/tests/smoke.robot
```
Expected: PASS (the run reports both `Keywords Resolve` and `Workflow Keywords Resolve` as passing; `--dryrun` resolves keywords/args without executing them).

- [ ] **Step 4: Commit**

```bash
git add tools/track-tester/resources/workflow.resource tools/track-tester/resources/tests/smoke.robot
git commit -m "test(dapr-workflow): add shared workflow keywords"
```

---

## Suite conventions (apply to Tasks 3–11)

Each `challenge.robot` follows this shape (concrete per-challenge values are given in each task):

- `*** Settings ***`: `Documentation`, `Resource ../../../tools/track-tester/resources/workflow.resource`, `Variables ../../../tools/track-tester/variables/dapr_workflow.py`, `Suite Teardown    Terminate All Processes    kill=True`.
- `*** Variables ***`: `${BASE}    ${WF_BASE}` plus per-language paths/ports and the log file `${LOG}    ${TEMPDIR}/dapr-workflow-chN.log`.
- Three test cases tagged `dotnet` / `java` / `python`. Each test:
  1. builds/installs (`Run And Expect RC Zero`),
  2. starts the app (`Start Workflow App`, which waits for readiness),
  3. starts the workflow + asserts status/output,
  4. has a `[Teardown]` that SIGINTs the app so the next test can reuse the port.
- **Python run command** carries the venv into `dapr run` via one shell: `bash -c 'source <inner>/venv/bin/activate && dapr run -f .'` executed from the challenge's Python dir (where `dapr.yaml` lives).
- A trailing `# doc-sync coverage:` comment block lists the assignment's `bash,run` command lines that are expressed via `cwd`/`bash -c` rather than appearing verbatim (e.g. `cd ...`, `source venv/bin/activate`). Step "verify docsync" in each task tells you exactly how to confirm/extend it.

---

## Task 3: Challenge 2 — fundamentals

**Files:**
- Create: `dapr-workflow/2-dapr-workflow-fundamentals/tests/challenge.robot`

- [ ] **Step 1: Write the suite**

```robotframework
*** Settings ***
Documentation     Drift test for dapr-workflow challenge 2 (fundamentals) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch2.log
${OUTPUT}     "One Two Three"

*** Test Cases ***
DotNet Fundamentals
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build Basic    ${WF_BASE}/csharp/fundamentals
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/fundamentals    ${LOG}    http://localhost:5254/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5254/start/One -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3554/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Fundamentals
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/fundamentals    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST "http://localhost:8080/start?input=One"
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    One Two Three

Python Fundamentals
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/fundamentals/basic
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/fundamentals/basic
    Start Workflow App    bash -c 'source basic/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/fundamentals    ${LOG}    http://localhost:5254/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5254/start/One -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3554/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/fundamentals
#   cd java/fundamentals
#   cd python/fundamentals/basic
#   source venv/bin/activate
#   cd ..
```

- [ ] **Step 2: Dry-run all three tests**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun ../../dapr-workflow/2-dapr-workflow-fundamentals/tests/challenge.robot
```
Expected: PASS (3 tests resolve).

- [ ] **Step 3: Verify docsync coverage**

Run:
```bash
cd tools/track-tester
uv run python docsync/check_doc_sync.py \
  ../../dapr-workflow/2-dapr-workflow-fundamentals/assignment.md \
  ../../dapr-workflow/2-dapr-workflow-fundamentals/tests/challenge.robot
```
Expected: `OK: all N runnable command(s) covered`. If it reports any uncovered `bash,run` command, add that exact line to the `# doc-sync coverage:` comment block and re-run until OK.

- [ ] **Step 4: Run the Python test end-to-end**

Ensure Docker is running and `dapr init` has been run once. Then:
```bash
cd tools/track-tester
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
uv run robot --include python ../../dapr-workflow/2-dapr-workflow-fundamentals/tests/challenge.robot
```
Expected: `Python Fundamentals` PASSES. (If `dotnet` is installed, also run `--include dotnet` and expect PASS.)

- [ ] **Step 5: Commit**

```bash
git add dapr-workflow/2-dapr-workflow-fundamentals/tests/challenge.robot
git commit -m "test(dapr-workflow): add challenge 2 (fundamentals) drift test"
```

---

## Task 4: Challenge 3 — task-chaining

**Files:**
- Create: `dapr-workflow/3-task-chaining/tests/challenge.robot`

- [ ] **Step 1: Write the suite**

```robotframework
*** Settings ***
Documentation     Drift test for dapr-workflow challenge 3 (task chaining) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch3.log
${OUTPUT}     "This is task chaining"

*** Test Cases ***
DotNet Task Chaining
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build TaskChaining    ${WF_BASE}/csharp/task-chaining
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/task-chaining    ${LOG}    http://localhost:5255/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5255/start -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3555/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Task Chaining
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/task-chaining    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST http://localhost:8080/start
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    This is task chaining

Python Task Chaining
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/task-chaining/task_chaining
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/task-chaining/task_chaining
    Start Workflow App    bash -c 'source task_chaining/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/task-chaining    ${LOG}    http://localhost:5255/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5255/start -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3555/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/task-chaining
#   cd java/task-chaining
#   cd python/task-chaining/task_chaining
#   source venv/bin/activate
#   cd ..
```

- [ ] **Step 2: Dry-run**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun ../../dapr-workflow/3-task-chaining/tests/challenge.robot
```
Expected: PASS.

- [ ] **Step 3: Verify docsync**

Run:
```bash
cd tools/track-tester
uv run python docsync/check_doc_sync.py \
  ../../dapr-workflow/3-task-chaining/assignment.md \
  ../../dapr-workflow/3-task-chaining/tests/challenge.robot
```
Expected: `OK`. If uncovered lines are reported, add them to the coverage comment and re-run.

- [ ] **Step 4: Run the Python test end-to-end**

Run:
```bash
cd tools/track-tester
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
uv run robot --include python ../../dapr-workflow/3-task-chaining/tests/challenge.robot
```
Expected: `Python Task Chaining` PASSES.

- [ ] **Step 5: Commit**

```bash
git add dapr-workflow/3-task-chaining/tests/challenge.robot
git commit -m "test(dapr-workflow): add challenge 3 (task chaining) drift test"
```

---

## Task 5: Challenge 4 — fan-out/fan-in

**Files:**
- Create: `dapr-workflow/4-fan-out-fan-in/tests/challenge.robot`

- [ ] **Step 1: Write the suite**

```robotframework
*** Settings ***
Documentation     Drift test for dapr-workflow challenge 4 (fan-out/fan-in) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch4.log
${OUTPUT}     "is"
${DATA}       ["which","word","is","the","shortest"]

*** Test Cases ***
DotNet Fan Out Fan In
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build FanOutFanIn    ${WF_BASE}/csharp/fan-out-fan-in
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/fan-out-fan-in    ${LOG}    http://localhost:5256/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5256/start --header 'content-type: application/json' --data '${DATA}' -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3556/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Fan Out Fan In
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/fan-out-fan-in    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST --url http://localhost:8080/start --header 'content-type: application/json' --data '${DATA}'
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    is

Python Fan Out Fan In
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/fan-out-fan-in/fan_out_fan_in
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/fan-out-fan-in/fan_out_fan_in
    Start Workflow App    bash -c 'source fan_out_fan_in/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/fan-out-fan-in    ${LOG}    http://localhost:5256/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5256/start --header 'content-type: application/json' --data '${DATA}' -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3556/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/fan-out-fan-in
#   cd java/fan-out-fan-in
#   cd python/fan-out-fan-in/fan_out_fan_in
#   source venv/bin/activate
#   cd ..
```

- [ ] **Step 2: Dry-run**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun ../../dapr-workflow/4-fan-out-fan-in/tests/challenge.robot
```
Expected: PASS.

- [ ] **Step 3: Verify docsync**

Run:
```bash
cd tools/track-tester
uv run python docsync/check_doc_sync.py \
  ../../dapr-workflow/4-fan-out-fan-in/assignment.md \
  ../../dapr-workflow/4-fan-out-fan-in/tests/challenge.robot
```
Expected: `OK`. Add any reported uncovered lines to the coverage comment and re-run.

- [ ] **Step 4: Run the Python test end-to-end**

Run:
```bash
cd tools/track-tester
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
uv run robot --include python ../../dapr-workflow/4-fan-out-fan-in/tests/challenge.robot
```
Expected: `Python Fan Out Fan In` PASSES.

- [ ] **Step 5: Commit**

```bash
git add dapr-workflow/4-fan-out-fan-in/tests/challenge.robot
git commit -m "test(dapr-workflow): add challenge 4 (fan-out/fan-in) drift test"
```

---

## Task 6: Challenge 5 — monitor

Note: the monitor workflow reschedules itself a random number of times before completing, so assert the deterministic prefix `Status is healthy after checking` (not the count) and allow a longer timeout. Also assert the per-language app-log activity marker appears.

**Files:**
- Create: `dapr-workflow/5-monitor/tests/challenge.robot`

- [ ] **Step 1: Write the suite**

```robotframework
*** Settings ***
Documentation     Drift test for dapr-workflow challenge 5 (monitor pattern) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch5.log
${OUTPUT}     Status is healthy after checking

*** Test Cases ***
DotNet Monitor
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build Monitor    ${WF_BASE}/csharp/monitor-pattern
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/monitor-pattern    ${LOG}    http://localhost:5257/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5257/start/0 -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Log Contains    ${LOG}    CheckStatus: Received input:    120s
    Wait Until Workflow Completed    http://localhost:3557/v1.0/workflows/dapr/${id}    ${OUTPUT}    timeout=180s

Java Monitor
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/monitor-pattern    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST http://localhost:8080/start/0
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    Status is healthy after checking    180s

Python Monitor
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/monitor-pattern/monitor
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/monitor-pattern/monitor
    Start Workflow App    bash -c 'source monitor/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/monitor-pattern    ${LOG}    http://localhost:5257/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5257/start/0 -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Log Contains    ${LOG}    check_status: Received input:    120s
    Wait Until Workflow Completed    http://localhost:3557/v1.0/workflows/dapr/${id}    ${OUTPUT}    timeout=180s

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/monitor-pattern
#   cd java/monitor-pattern
#   cd python/monitor-pattern/monitor
#   source venv/bin/activate
#   cd ..
```

- [ ] **Step 2: Dry-run**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun ../../dapr-workflow/5-monitor/tests/challenge.robot
```
Expected: PASS.

- [ ] **Step 3: Verify docsync**

Run:
```bash
cd tools/track-tester
uv run python docsync/check_doc_sync.py \
  ../../dapr-workflow/5-monitor/assignment.md \
  ../../dapr-workflow/5-monitor/tests/challenge.robot
```
Expected: `OK`. Add any reported uncovered lines to the coverage comment and re-run.

- [ ] **Step 4: Run the Python test end-to-end**

Run:
```bash
cd tools/track-tester
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
uv run robot --include python ../../dapr-workflow/5-monitor/tests/challenge.robot
```
Expected: `Python Monitor` PASSES (may take a couple of minutes as the monitor loops).

- [ ] **Step 5: Commit**

```bash
git add dapr-workflow/5-monitor/tests/challenge.robot
git commit -m "test(dapr-workflow): add challenge 5 (monitor) drift test"
```

---

## Task 7: Challenge 6 — external events

Note: the instance ID is fixed (it is the order ID `b7dd836b-...`), so no capture is needed. The workflow waits for an external `approval-event`; .NET/Python raise it via the Dapr API, Java via the app's `/event` endpoint. Field casing differs per language (`IsApproved` / `isApproved` / `is_approved`, and `total_price` in Python's order body).

**Files:**
- Create: `dapr-workflow/6-external-events/tests/challenge.robot`

- [ ] **Step 1: Write the suite**

```robotframework
*** Settings ***
Documentation     Drift test for dapr-workflow challenge 6 (external events) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch6.log
${ORDER_ID}   b7dd836b-e913-4446-9912-d400befebec5
${OUTPUT}     has been approved

*** Test Cases ***
DotNet External Events
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build ExternalEvents    ${WF_BASE}/csharp/external-system-interaction
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/external-system-interaction    ${LOG}    http://localhost:5258/
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5258/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","description": "Rubber ducks","quantity": 100,"totalPrice": 500}'
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:3558/v1.0/workflows/dapr/${ORDER_ID}/raiseEvent/approval-event --header 'content-type: application/json' --data '{"OrderId": "${ORDER_ID}","IsApproved": true}'
    Wait Until Workflow Completed    http://localhost:3558/v1.0/workflows/dapr/${ORDER_ID}    ${OUTPUT}

Java External Events
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/external-system-interactions    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:8080/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","description": "Rubber ducks","quantity": 100,"totalPrice": 500}'
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:8080/event --header 'content-type: application/json' --data '{"orderId": "${ORDER_ID}","isApproved": true}'
    Wait Until Command Output Contains    curl -s http://localhost:8080/status    COMPLETED

Python External Events
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/external-system-interaction/external_events
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/external-system-interaction/external_events
    Start Workflow App    bash -c 'source external_events/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/external-system-interaction    ${LOG}    http://localhost:5258/
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5258/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","description": "Rubber ducks","quantity": 100,"total_price": 500}'
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:3558/v1.0/workflows/dapr/${ORDER_ID}/raiseEvent/approval-event --header 'content-type: application/json' --data '{"order_id": "${ORDER_ID}","is_approved": true}'
    Wait Until Workflow Completed    http://localhost:3558/v1.0/workflows/dapr/${ORDER_ID}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/external-system-interaction
#   cd java/external-system-interactions
#   cd python/external-system-interaction/external_events
#   source venv/bin/activate
#   cd ..
```

- [ ] **Step 2: Dry-run**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun ../../dapr-workflow/6-external-events/tests/challenge.robot
```
Expected: PASS.

- [ ] **Step 3: Verify docsync**

Run:
```bash
cd tools/track-tester
uv run python docsync/check_doc_sync.py \
  ../../dapr-workflow/6-external-events/assignment.md \
  ../../dapr-workflow/6-external-events/tests/challenge.robot
```
Expected: `OK`. Add any reported uncovered lines to the coverage comment and re-run.

- [ ] **Step 4: Run the Python test end-to-end**

Run:
```bash
cd tools/track-tester
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
uv run robot --include python ../../dapr-workflow/6-external-events/tests/challenge.robot
```
Expected: `Python External Events` PASSES.

- [ ] **Step 5: Commit**

```bash
git add dapr-workflow/6-external-events/tests/challenge.robot
git commit -m "test(dapr-workflow): add challenge 6 (external events) drift test"
```

---

## Task 8: Challenge 7 — child workflows

**Files:**
- Create: `dapr-workflow/7-child-workflows/tests/challenge.robot`

- [ ] **Step 1: Write the suite**

```robotframework
*** Settings ***
Documentation     Drift test for dapr-workflow challenge 7 (child workflows) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch7.log
${OUTPUT}     Item 1 is processed as a child workflow.
${DATA}       ["Item 1","Item 2"]

*** Test Cases ***
DotNet Child Workflows
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build ChildWorkflows    ${WF_BASE}/csharp/child-workflows
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/child-workflows    ${LOG}    http://localhost:5259/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5259/start --header 'content-type: application/json' --data '${DATA}' -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3559/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Child Workflows
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/child-workflows    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST --url http://localhost:8080/start --header 'content-type: application/json' --data '${DATA}'
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    Item 1 is processed as a child workflow.

Python Child Workflows
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/child-workflows/child_workflows
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/child-workflows/child_workflows
    Start Workflow App    bash -c 'source child_workflows/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/child-workflows    ${LOG}    http://localhost:5259/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5259/start --header 'content-type: application/json' --data '${DATA}' -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3559/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/child-workflows
#   cd java/child-workflows
#   cd python/child-workflows/child_workflows
#   source venv/bin/activate
#   cd ..
```

- [ ] **Step 2: Dry-run**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun ../../dapr-workflow/7-child-workflows/tests/challenge.robot
```
Expected: PASS.

- [ ] **Step 3: Verify docsync**

Run:
```bash
cd tools/track-tester
uv run python docsync/check_doc_sync.py \
  ../../dapr-workflow/7-child-workflows/assignment.md \
  ../../dapr-workflow/7-child-workflows/tests/challenge.robot
```
Expected: `OK`. Add any reported uncovered lines to the coverage comment and re-run.

- [ ] **Step 4: Run the Python test end-to-end**

Run:
```bash
cd tools/track-tester
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
uv run robot --include python ../../dapr-workflow/7-child-workflows/tests/challenge.robot
```
Expected: `Python Child Workflows` PASSES.

- [ ] **Step 5: Commit**

```bash
git add dapr-workflow/7-child-workflows/tests/challenge.robot
git commit -m "test(dapr-workflow): add challenge 7 (child workflows) drift test"
```

---

## Task 9: Challenge 8 — resiliency and compensation

Note: the workflow is started with input `1` and its output is `1`; assert the exact `"dapr.workflow.output":"1"` marker so the assertion is specific.

**Files:**
- Create: `dapr-workflow/8-resiliency-and-compensation/tests/challenge.robot`

- [ ] **Step 1: Write the suite**

```robotframework
*** Settings ***
Documentation     Drift test for dapr-workflow challenge 8 (resiliency & compensation) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch8.log
${OUTPUT}     "dapr.workflow.output":"1"

*** Test Cases ***
DotNet Resiliency
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build ResiliencyAndCompensation    ${WF_BASE}/csharp/resiliency-and-compensation
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/resiliency-and-compensation    ${LOG}    http://localhost:5264/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5264/start/1 -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3564/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Resiliency
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/resiliency-and-compensation    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST --url http://localhost:8080/start/1
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    1

Python Resiliency
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/resiliency-and-compensation/resiliency_and_compensation
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/resiliency-and-compensation/resiliency_and_compensation
    Start Workflow App    bash -c 'source resiliency_and_compensation/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/resiliency-and-compensation    ${LOG}    http://localhost:5264/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5264/start/1 -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3564/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/resiliency-and-compensation
#   cd java/resiliency-and-compensation
#   cd python/resiliency-and-compensation/resiliency_and_compensation
#   source venv/bin/activate
#   cd ..
```

- [ ] **Step 2: Dry-run**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun ../../dapr-workflow/8-resiliency-and-compensation/tests/challenge.robot
```
Expected: PASS.

- [ ] **Step 3: Verify docsync**

Run:
```bash
cd tools/track-tester
uv run python docsync/check_doc_sync.py \
  ../../dapr-workflow/8-resiliency-and-compensation/assignment.md \
  ../../dapr-workflow/8-resiliency-and-compensation/tests/challenge.robot
```
Expected: `OK`. Add any reported uncovered lines to the coverage comment and re-run.

- [ ] **Step 4: Run the Python test end-to-end**

Run:
```bash
cd tools/track-tester
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
uv run robot --include python ../../dapr-workflow/8-resiliency-and-compensation/tests/challenge.robot
```
Expected: `Python Resiliency` PASSES.

- [ ] **Step 5: Commit**

```bash
git add dapr-workflow/8-resiliency-and-compensation/tests/challenge.robot
git commit -m "test(dapr-workflow): add challenge 8 (resiliency & compensation) drift test"
```

---

## Task 10: Challenge 9 — combined patterns

Note: two apps. .NET/Python run both via one `dapr run -f .` (single `app` alias); **Java runs two separate `mvn` background processes** (`app` = workflow-app, `shipping` = shipping-app), each with `--reuse=true`. Instance ID is fixed (`b0d38481-...`). Order-body casing differs (.NET/Java camelCase `orderItem`/`customerInfo`; Python snake_case `order_item`/`customer_info`). Output differs by language but all contain `processed successfully`.

**Files:**
- Create: `dapr-workflow/9-combined-patterns/tests/challenge.robot`

- [ ] **Step 1: Write the suite**

```robotframework
*** Settings ***
Documentation     Drift test for dapr-workflow challenge 9 (combined patterns) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}         ${TEMPDIR}/dapr-workflow-ch9.log
${LOG2}        ${TEMPDIR}/dapr-workflow-ch9-shipping.log
${ORDER_ID}    b0d38481-5547-411e-ae7b-255761cce17a
${OUTPUT}      processed successfully

*** Test Cases ***
DotNet Combined Patterns
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build ShippingApp    ${WF_BASE}/csharp/combined-patterns
    Run And Expect RC Zero    dotnet build WorkflowApp    ${WF_BASE}/csharp/combined-patterns
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/combined-patterns    ${LOG}    http://localhost:5260/
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5260/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","orderItem" : {"productId": "RBD001","productName": "Rubber Duck","quantity": 10,"totalPrice": 15.00},"customerInfo" : {"id" : "Customer1","country" : "The Netherlands"}}'
    Wait Until Workflow Completed    http://localhost:3560/v1.0/workflows/dapr/${ORDER_ID}    ${OUTPUT}

Java Combined Patterns
    [Tags]    java
    [Teardown]    Run Keywords    Stop Process With SIGINT    app    AND    Stop Process With SIGINT    shipping
    Start Workflow App    mvn clean -Dspring-boot.run.arguments="--reuse=true" spring-boot:test-run    ${WF_BASE}/java/combined-patterns/workflow-app    ${LOG}    http://localhost:8080/    app    timeout=300s
    Start Background Process    mvn clean -Dspring-boot.run.arguments="--reuse=true" spring-boot:test-run    ${LOG2}    shipping    cwd=${WF_BASE}/java/combined-patterns/shipping-app
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:8080/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","orderItem" : {"productId": "RBD001","productName": "Rubber Duck","quantity": 10,"totalPrice": 15.00},"customerInfo" : {"id" : "Customer1","country" : "The Netherlands"}}'
    Wait Until Command Output Contains    curl -s "http://localhost:8080/output?instanceId=${ORDER_ID}"    processed successfully    180s

Python Combined Patterns
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/combined-patterns
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/combined-patterns/workflow_app
    Run And Expect RC Zero    bash -c 'source ../venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/combined-patterns/shipping_app
    Start Workflow App    bash -c 'source venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/combined-patterns    ${LOG}    http://localhost:5260/
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5260/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","order_item" : {"product_id": "RBD001","product_name": "Rubber Duck","quantity": 10,"total_price": 15.00},"customer_info" : {"id" : "Customer1","country" : "The Netherlands"}}'
    Wait Until Workflow Completed    http://localhost:3560/v1.0/workflows/dapr/${ORDER_ID}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/combined-patterns
#   cd java/combined-patterns/workflow-app
#   cd java/combined-patterns/shipping-app
#   cd python/combined-patterns
#   source venv/bin/activate
#   cd workflow_app
#   cd ..
#   cd shipping_app
```

- [ ] **Step 2: Dry-run**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun ../../dapr-workflow/9-combined-patterns/tests/challenge.robot
```
Expected: PASS.

- [ ] **Step 3: Verify docsync**

Run:
```bash
cd tools/track-tester
uv run python docsync/check_doc_sync.py \
  ../../dapr-workflow/9-combined-patterns/assignment.md \
  ../../dapr-workflow/9-combined-patterns/tests/challenge.robot
```
Expected: `OK`. The combined-patterns assignment has more `bash,run` lines (two build/install blocks); add any reported uncovered lines to the coverage comment and re-run until OK.

- [ ] **Step 4: Run the Python test end-to-end**

Run:
```bash
cd tools/track-tester
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
uv run robot --include python ../../dapr-workflow/9-combined-patterns/tests/challenge.robot
```
Expected: `Python Combined Patterns` PASSES.

- [ ] **Step 5: Commit**

```bash
git add dapr-workflow/9-combined-patterns/tests/challenge.robot
git commit -m "test(dapr-workflow): add challenge 9 (combined patterns) drift test"
```

---

## Task 11: Challenge 10 — workflow management

Note: `neverendingworkflow` never completes on its own. All management operations use the **app's own endpoints** (on `5262` for .NET/Python, `8080` for Java): `/start/0`, `/status/<id>`, `/suspend/<id>`, `/resume/<id>`, `/terminate/<id>`, `/purge/<id>`. Assert the status transitions `RUNNING → SUSPENDED → RUNNING → TERMINATED`, and that each management call succeeds. Java's `/start/0` returns the instance ID as the plain response body.

**Files:**
- Create: `dapr-workflow/10-workflow-management/tests/challenge.robot`

- [ ] **Step 1: Write the suite**

```robotframework
*** Settings ***
Documentation     Drift test for dapr-workflow challenge 10 (workflow management) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch10.log

*** Test Cases ***
DotNet Workflow Management
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build WorkflowManagement    ${WF_BASE}/csharp/workflow-management
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/workflow-management    ${LOG}    http://localhost:5262/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5262/start/0 -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Manage Workflow Lifecycle    http://localhost:5262    ${id}

Java Workflow Management
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/workflow-management    ${LOG}    http://localhost:8080/    timeout=300s
    ${id}=    Capture Command Output    curl -s --request POST --url http://localhost:8080/start/0
    Manage Workflow Lifecycle    http://localhost:8080    ${id}

Python Workflow Management
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/workflow-management/workflow_management
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/workflow-management/workflow_management
    Start Workflow App    bash -c 'source workflow_management/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/workflow-management    ${LOG}    http://localhost:5262/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5262/start/0 -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Manage Workflow Lifecycle    http://localhost:5262    ${id}

*** Keywords ***
Manage Workflow Lifecycle
    # Exercises the suspend/resume/terminate/purge management endpoints against the
    # given app base URL and instance id, asserting the status transitions.
    [Arguments]    ${base}    ${id}
    Wait Until Command Output Contains    curl -s ${base}/status/${id}    RUNNING
    Run And Expect RC Zero    curl -i --request POST --url ${base}/suspend/${id}
    Wait Until Command Output Contains    curl -s ${base}/status/${id}    SUSPENDED
    Run And Expect RC Zero    curl -i --request POST --url ${base}/resume/${id}
    Wait Until Command Output Contains    curl -s ${base}/status/${id}    RUNNING
    Run And Expect RC Zero    curl -i --request POST --url ${base}/terminate/${id}
    Wait Until Command Output Contains    curl -s ${base}/status/${id}    TERMINATED
    Run And Expect RC Zero    curl -i --request DELETE --url ${base}/purge/${id}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/workflow-management
#   cd java/workflow-management
#   cd python/workflow-management/workflow_management
#   source venv/bin/activate
#   cd ..
```

- [ ] **Step 2: Dry-run**

Run:
```bash
cd tools/track-tester
uv run robot --dryrun ../../dapr-workflow/10-workflow-management/tests/challenge.robot
```
Expected: PASS.

- [ ] **Step 3: Verify docsync**

Run:
```bash
cd tools/track-tester
uv run python docsync/check_doc_sync.py \
  ../../dapr-workflow/10-workflow-management/assignment.md \
  ../../dapr-workflow/10-workflow-management/tests/challenge.robot
```
Expected: `OK`. Add any reported uncovered lines to the coverage comment and re-run.

- [ ] **Step 4: Run the Python test end-to-end**

Run:
```bash
cd tools/track-tester
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
uv run robot --include python ../../dapr-workflow/10-workflow-management/tests/challenge.robot
```
Expected: `Python Workflow Management` PASSES.

- [ ] **Step 5: Commit**

```bash
git add dapr-workflow/10-workflow-management/tests/challenge.robot
git commit -m "test(dapr-workflow): add challenge 10 (workflow management) drift test"
```

---

## Task 12: CI setup script

**Files:**
- Create: `tools/track-tester/ci/setup-dapr-workflow.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks. Reads optional `QUICKSTARTS_DIR` env var.
- Produces: a reproducible sandbox — cloned quickstarts, `uv` installed, Dapr CLI installed + `dapr init` done.

- [ ] **Step 1: Write the setup script**

```bash
#!/usr/bin/env bash
# Reproduce the dapr-workflow sandbox environment in CI.
# Mirrors ci/setup-dapr-101.sh, but the dapr-workflow track installs the Dapr CLI
# from master (its _setup/sandbox-setup.sh does not pin a version), so there is no
# version pin here. Language runtimes are provisioned by the workflow's
# setup-dotnet/setup-java steps, not by this script.
set -euo pipefail

QUICKSTARTS_DIR="${QUICKSTARTS_DIR:-$HOME/quickstarts}"

# 1. Clone the quickstarts repo (drift source of truth).
if [ ! -d "$QUICKSTARTS_DIR/.git" ]; then
  git clone --depth 1 https://github.com/dapr/quickstarts.git "$QUICKSTARTS_DIR"
fi

# 2. Install uv (used to run robot).
# curl (not wget) so this runs on macOS too — macOS ships curl but not wget.
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# 3. Install the Dapr CLI (latest, matching the track's sandbox-setup.sh) and init.
if ! command -v dapr >/dev/null 2>&1; then
  wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
fi
dapr uninstall --all >/dev/null || true
dapr init

echo "Setup complete. QUICKSTARTS_DIR=$QUICKSTARTS_DIR"
```

- [ ] **Step 2: Make it executable and shell-check the syntax**

Run:
```bash
chmod +x tools/track-tester/ci/setup-dapr-workflow.sh
bash -n tools/track-tester/ci/setup-dapr-workflow.sh && echo "syntax OK"
```
Expected: prints `syntax OK` (no output from `bash -n` means valid syntax).

- [ ] **Step 3: Commit**

```bash
git add tools/track-tester/ci/setup-dapr-workflow.sh
git commit -m "ci(dapr-workflow): add sandbox setup script"
```

---

## Task 13: CI workflow

**Files:**
- Create: `.github/workflows/test-dapr-workflow.yml`

**Interfaces:**
- Consumes: `ci/setup-dapr-workflow.sh` (Task 12) and all 9 challenge suites (Tasks 3–11).

- [ ] **Step 1: Write the workflow**

```yaml
name: Test dapr-workflow track

on:
  schedule:
    - cron: '30 6 * * 1'   # Mondays 06:30 UTC (offset from dapr-101's 06:00)
  workflow_dispatch:
  pull_request:
    paths:
      - 'dapr-workflow/**'
      - 'tools/track-tester/**'

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
          for ch in 2-dapr-workflow-fundamentals 3-task-chaining 4-fan-out-fan-in \
                    5-monitor 6-external-events 7-child-workflows \
                    8-resiliency-and-compensation 9-combined-patterns \
                    10-workflow-management; do
            uv run python docsync/check_doc_sync.py \
              ../../dapr-workflow/$ch/assignment.md \
              ../../dapr-workflow/$ch/tests/challenge.robot
          done

  languages:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        lang: [dotnet, java, python]
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - name: Set up .NET
        if: matrix.lang == 'dotnet'
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: |
            8.0.x
            9.0.x
      - name: Set up Java
        if: matrix.lang == 'java'
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - name: Set up Python
        if: matrix.lang == 'python'
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Setup Dapr sandbox
        run: bash tools/track-tester/ci/setup-dapr-workflow.sh
      - name: Sync harness
        run: (cd tools/track-tester && uv sync)
      - name: Run all workflow challenges for ${{ matrix.lang }}
        run: |
          cd tools/track-tester
          for ch in 2-dapr-workflow-fundamentals:ch2 3-task-chaining:ch3 \
                    4-fan-out-fan-in:ch4 5-monitor:ch5 6-external-events:ch6 \
                    7-child-workflows:ch7 8-resiliency-and-compensation:ch8 \
                    9-combined-patterns:ch9 10-workflow-management:ch10; do
            dir="${ch%%:*}"; out="${ch##*:}"
            uv run robot --outputdir "results/$out" --include ${{ matrix.lang }} \
              "../../dapr-workflow/$dir/tests/challenge.robot"
          done
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: robot-${{ matrix.lang }}
          path: tools/track-tester/results/

  report:
    needs: [docsync, languages]
    if: failure() && github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const title = 'Dapr Workflow track drift detected';
            const runUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
            const body = [
              `The scheduled dapr-workflow drift test **failed**.`,
              ``,
              `- Run: ${runUrl}`,
              `- Download the \`robot-*\` artifacts for the failing language and open \`log.html\`.`,
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

- [ ] **Step 2: Validate the YAML parses**

Run:
```bash
cd tools/track-tester
uv run python -c "import yaml,sys; yaml.safe_load(open('../../.github/workflows/test-dapr-workflow.yml')); print('yaml OK')"
```
Expected: prints `yaml OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/test-dapr-workflow.yml
git commit -m "ci(dapr-workflow): add drift-test workflow"
```

- [ ] **Step 4: Update the harness README**

Add a short note to `tools/track-tester/README.md` (under "Running locally") documenting the workflow suites, mirroring the dapr-101 examples. Insert after the existing dapr-101 example block:

```markdown

### dapr-workflow suites

The dapr-workflow suites live at `dapr-workflow/<n>-<name>/tests/challenge.robot` and
share `resources/workflow.resource` + `variables/dapr_workflow.py`. They run the same
way; e.g. one challenge for one language:

​```bash
export QUICKSTARTS_DIR="$HOME/dev/dapr/quickstarts"
(cd tools/track-tester && uv run robot --include python \
  ../../dapr-workflow/3-task-chaining/tests/challenge.robot)
​```

The Java tests use `mvn spring-boot:test-run` (Testcontainers-based Dapr) and need
Docker running; they do not use `dapr run`. The .NET/Python tests use `dapr run -f .`
and require `dapr init`.
```

(Remove the zero-width space characters shown around the inner code fence — they are only here to nest the fence inside this plan.)

- [ ] **Step 5: Commit the README update**

```bash
git add tools/track-tester/README.md
git commit -m "docs(track-tester): document dapr-workflow suites"
```

---

## Self-Review Notes

- **Spec coverage:** variables file (T1), workflow.resource (T2), 9 suites for challenges 2–10 (T3–T11), docsync verified per challenge (steps in T3–T11) + CI docsync job (T13), setup script (T12), CI workflow (T13), README (T13). All spec sections covered.
- **Deferred spec items resolved:** readiness marker → replaced with a language-agnostic HTTP port probe (`Wait Until App Responds`), removing dependence on framework log strings; Python venv-into-`dapr-run` → single `bash -c 'source .../venv/bin/activate && dapr run -f .'` invocation.
- **Type/keyword consistency:** every suite uses only keywords defined in `dapr.resource` (existing) or `workflow.resource` (T2): `Run And Expect RC Zero`, `Start Background Process`, `Stop Process With SIGINT`, `Wait Until Log Contains`, `Terminate All Processes`, `Start Workflow App`, `Wait Until App Responds`, `Capture Command Output`, `Wait Until Command Output Contains`, `Wait Until Workflow Completed`. The per-suite `Manage Workflow Lifecycle` (T11) is defined in its own suite.
- **Known risk to watch during execution:** Java folder name for ch6 is `external-system-interactions` (plural) — used in T7. Java ch9 needs two `mvn` processes and the shipping-app port is not asserted directly (readiness is probed on 8080; the workflow retries the shipping call). If a Java run flakes on shipping readiness, add a `Wait Until App Responds` for the shipping port once its port is confirmed from the app config.
