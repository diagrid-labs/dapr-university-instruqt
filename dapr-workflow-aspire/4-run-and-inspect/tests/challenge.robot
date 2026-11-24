*** Settings ***
Name              Ch4 Run And Inspect
Documentation     Drift test for dapr-workflow-aspire page 4: the learner starts diagnostics runs with curl,
...               reads their status and their history in the Dev Dashboard, and stops and starts the
...               engineering resource in the middle of a run to see the workflow carry on.
...
...               The suite starts from page 3's end state (rebuilt from pages 1 to 3 when SOLUTION_DIR
...               does not hold it) and starts its own `aspire run` with the page's command (the page 3
...               suite stops its own). It runs the page's curl and `aspire resource` commands as they
...               are, from the folder the page's `cd` names. The readings and the officer are random,
...               so it asserts the shape of each result, never a fixed priority.
...
...               Review Focus 4: the check runs right after the start, during the 15 second timer,
...               and must ask to wait; after the run completes it must pass. Review Focus 5: with
...               engineering stopped, the api condition fails (its failure_message says how to start it
...               again) and the completed check leaves the hint to it.
Library           Collections
Library           OperatingSystem
Library           String
Library           ../../../tools/track-tester/libraries/assignment_blocks.py
Resource          ../../../tools/track-tester/resources/aspire.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_aspire.py
Suite Setup       Start From Page 3 And Run Aspire
Suite Teardown    Run Keywords
...               Capture Aspire Logs And Stop App    ${APPHOST}    ports=${APP_PORTS}
...               AND    Terminate All Processes    kill=True

*** Variables ***
${ASSIGNMENT}       ${CURDIR}/../assignment.md
${PAGE1}            ${CURDIR}/../../1-create-the-solution/assignment.md
${PAGE2}            ${CURDIR}/../../2-write-the-workflow/assignment.md
${PAGE3}            ${CURDIR}/../../3-orchestrate-with-aspire/assignment.md
${CHECK_COMPLETED}  ${CURDIR}/../scripts/check-completed.sh
${CHECK_API}        ${CURDIR}/../../3-orchestrate-with-aspire/scripts/check-api.sh
${TASKS}            ${CURDIR}/../../tasks.hcl
@{NO_COPY_BLOCKS}
# The VM's checkout, as the pages' `cd` names it.
${VM_CHECKOUT}      /root/university-labs
${APPHOST}          ${SOLUTION_DIR}${/}apphost.cs
${ENGINEERING}      ${SOLUTION_DIR}${/}Engineering
${LOG}              ${OUTPUT DIR}${/}aspire-run.log
# The engineering API, the Dev Dashboard and the Aspire dashboard.
@{APP_PORTS}        5411    9090    17000
@{SUBSYSTEMS}       WarpCore    LifeSupport    Shields
@{PRIORITIES}       Urgent    Elevated    Routine

*** Test Cases ***
The Check Fails Before Any Run
    The Api Check Passes
    ${check}=    Run Completed Check
    Should Not Be Equal As Integers    ${check.rc}    0    msg=check-completed.sh passed before any run:\n${check.stdout}
    Should Contain    ${check.stdout}    No diagnostics run was found
    ${code}=    Capture Command Output    curl -s -o /dev/null -w '\%{http_code}' ${APP_URL}/status/jump-unknown
    Should Be Equal    ${code}    404    msg=the status of an unknown ID is not 404

The Check Asks To Wait During The Timer
    [Documentation]    Review Focus 4: the learner selects Check right after starting jump-001.
    ${out}=    Run Page Command    "id":"jump-001"
    ${started}=    Evaluate    json.loads($out)    modules=json
    Should Be Equal    ${started}    ${{ {"instanceId": "jump-001"} }}
    Assignment Should Contain    "instanceId": "jump-001"
    ${check}=    Run Completed Check
    Should Not Be Equal As Integers    ${check.rc}    0    msg=check-completed.sh passed during the timer:\n${check.stdout}
    Should Contain    ${check.stdout}    jump-001 is Running
    Should Contain    ${check.stdout}    wait until it completes, then check again
    # The page's status command shows what the page says: Running, no output yet.
    ${status}=    Run Page Command    /status/jump-001
    ${status}=    Evaluate    json.loads($status)    modules=json
    Should Be Equal    ${status}    ${{ {"status": "Running", "output": None} }}
    Assignment Should Contain    "status": "Running",\n${SPACE * 2}"output": null

Starting A Running ID Again Fails
    [Documentation]    The page says an ID must not be running: a second start of jump-001 during its
    ...    timer fails with "an active workflow with ID ... already exists".
    ${status}=    Run Status    jump-001
    Should Be Equal    ${status}[status]    Running
    ${start}=    Get Command Containing    ${ASSIGNMENT}    "id":"jump-001"
    ${raw}=    Remove String    ${start}    ${SPACE}| jq
    ${r}=    Run Process    ${raw} -w '\\n\%{http_code}'    shell=True    cwd=${WORKSPACE}
    Should End With    ${r.stdout}    500
    Should Contain    ${r.stdout}    an active workflow with ID 'jump-001' already exists
    Assignment Should Contain    an active workflow with that ID already exists

The Run Completes And The Check Passes
    Wait Until Run Is    jump-001    Completed    timeout=60s
    ${status}=    Run Page Command    /status/jump-001
    ${status}=    Evaluate    json.loads($status)    modules=json
    Should Be Equal    ${status}[status]    Completed
    Output Should Have The Page Shape    ${status}[output]    47634.4
    The Api Check Passes
    ${check}=    Run Completed Check
    Should Be Equal As Integers    ${check.rc}    0    msg=check-completed.sh failed after the run completed:\n${check.stdout}

The Dev Dashboard Lists jump-001 With Its History
    ${list}=    Capture Command Output    curl -sf -H 'Host: localhost:9090' ${DEV_DASHBOARD_URL}/api/workflows
    ${items}=    Evaluate    [w for w in json.loads($list)["items"] if w["instanceId"] == "jump-001" and w["appId"] == "engineering"]
    ...    modules=json
    Length Should Be    ${items}    1
    Should Be Equal    ${items}[0][name]    DiagnosticsWorkflow
    Should Be Equal    ${items}[0][status]    Completed
    ${history}=    History Of    jump-001
    Should Be Equal As Integers    ${{ $history["scheduled"].count("DiagnoseSubsystemActivity") }}    3
    Should Contain    ${history}[scheduled]    PrioritizeDiagnosticsActivity
    FOR    ${type}    IN    ExecutionStarted    TaskScheduled    TaskCompleted    TimerCreated    TimerFired
    ...    ExecutionCompleted
        List Should Contain Value    ${history}[types]    ${type}
        Assignment Should Contain    `${type}`
    END
    # The timer waited 15 seconds.
    Should Be True    ${history}[timer_seconds] >= 14    msg=the timer fired after ${history}[timer_seconds] s
    Assignment Should Contain    **Workflows** page

Stopping Engineering Mid-Run Keeps The Sidecar And The History
    [Documentation]    Risk 2 and Review Focus 5: the learner starts jump-002 and stops engineering
    ...    during its timer with the page's command. The sidecar keeps running, the run stays Running
    ...    with its three diagnoses in the history, the api condition fails, and the completed
    ...    check leaves the hint to it.
    ${out}=    Run Page Command    "id":"jump-002"
    Should Be Equal    ${{ json.loads($out) }}    ${{ {"instanceId": "jump-002"} }}
    Sleep    2s    reason=the three diagnoses finish within a second; stop during the timer
    Run Page Command    aspire resource engineering stop
    ${stopped_at}=    Evaluate    datetime.datetime.now(datetime.timezone.utc)    modules=datetime
    Set Suite Variable    ${STOPPED_AT}    ${stopped_at}
    ${states}=    Resource States
    Should Be Equal    ${states}[engineering]    Finished
    Should Be Equal    ${states}[engineering-dapr-cli]    Running
    Assignment Should Contain    Its state changes to `Finished`
    ${history}=    History Of    jump-002
    Should Be Equal    ${history}[status]    Running
    Should Be Equal As Integers    ${{ $history["scheduled"].count("DiagnoseSubsystemActivity") }}    3
    List Should Contain Value    ${history}[types]    TimerCreated
    List Should Not Contain Value    ${history}[types]    TimerFired
    Set Suite Variable    ${READINGS_BEFORE}    ${history}[results]
    # Review Focus 5: the api condition fails, and its message names the page's start command.
    ${check}=    Run Process    bash    ${CHECK_API}    stderr=STDOUT    timeout=60s
    Should Not Be Equal As Integers    ${check.rc}    0    msg=check-api.sh passed with engineering stopped
    Should Contain    ${check.stdout}    does not answer
    ${start}=    Get Command Containing    ${ASSIGNMENT}    aspire resource engineering start
    ${tasks}=    Get File    ${TASKS}
    Should Contain    ${tasks}    ${start} in the curl window
    ${check}=    Run Completed Check
    Should Be Equal As Integers    ${check.rc}    0    msg=check-completed.sh failed instead of leaving the hint to the api check:\n${check.stdout}
    Should Contain    ${check.stdout}    does not answer

Starting Engineering Again Resumes The Run
    [Documentation]    Risk 2: the page's start command brings engineering back, jump-002 completes
    ...    without a new start, and the three diagnoses did not run again: one TaskScheduled each,
    ...    all from before the stop, with the same results.
    # Stay stopped past the timer's due time, as a learner who reads the Dev Dashboard first does.
    Sleep    16s
    # The time before the start command: the run carries on while the command still waits for the
    # resource to report Running.
    ${started_at}=    Evaluate    datetime.datetime.now(datetime.timezone.utc)    modules=datetime
    Run Page Command    aspire resource engineering start
    Wait Until App Responds    ${APP_URL}    timeout=60s
    Wait Until Run Is    jump-002    Completed    timeout=60s
    ${status}=    Run Page Command    /status/jump-002
    ${status}=    Evaluate    json.loads($status)    modules=json
    Output Should Have The Page Shape    ${status}[output]    47634.5
    ${history}=    History Of    jump-002
    Should Be Equal As Integers    ${{ $history["scheduled"].count("DiagnoseSubsystemActivity") }}    3
    Should Be Equal    ${history}[results]    ${READINGS_BEFORE}    msg=the diagnoses returned other results after the restart
    # A lambda, because a generator in Evaluate cannot see Robot variables.
    ${early}=    Evaluate    (lambda s, ts: len(ts) == 3 and all(t < s for t in ts))($STOPPED_AT, $history["diagnose_times"])
    Should Be True    ${early}    msg=a DiagnoseSubsystemActivity was scheduled after the stop
    ${late}=    Evaluate    $history["timer_fired"] is not None and $history["timer_fired"] > $started_at
    Should Be True    ${late}    msg=TimerFired is not from after the restart
    List Should Contain Value    ${history}[types]    ExecutionCompleted
    The Api Check Passes
    ${check}=    Run Completed Check
    Should Be Equal As Integers    ${check.rc}    0    msg=check-completed.sh failed:\n${check.stdout}

A Completed ID Starts A New Run
    [Documentation]    The page says a completed ID starts a new run that replaces the old one.
    ${out}=    Run Page Command    "id":"jump-001"
    Should Be Equal    ${{ json.loads($out) }}    ${{ {"instanceId": "jump-001"} }}
    ${status}=    Run Status    jump-001
    Should Be Equal    ${status}[status]    Running
    Wait Until Run Is    jump-001    Completed    timeout=60s
    Assignment Should Contain    the same ID starts a new run that replaces the old one

*** Keywords ***
Start From Page 3 And Run Aspire
    # Page 4 starts where page 3 ends. When the earlier suites did not run first (a local run of
    # this suite alone), rebuild pages 1 to 3 from their assignments. (Robot variables ignore case,
    # so the flags must not be named like ${PAGE1}.)
    ${has_profile}=    Run Keyword And Return Status    File Should Exist    ${SOLUTION_DIR}${/}apphost.run.json
    ${has_project}=    Run Keyword And Return Status    File Should Exist    ${ENGINEERING}${/}Engineering.csproj
    IF    not ${has_profile} or not ${has_project}
        Remove Directory    ${SOLUTION_DIR}    recursive=True
        Apply Challenge    ${PAGE1}    ${WORKSPACE}    ${SOLUTION_DIR}    ${NO_COPY_BLOCKS}
        ...    rewrite_from=${VM_CHECKOUT}    rewrite_to=${TRACKS_SRC_DIR}
    END
    ${has_workflow}=    Run Keyword And Return Status    File Should Exist    ${ENGINEERING}${/}DiagnosticsWorkflow.cs
    ${built}=    Run Keyword And Return Status    File Should Exist
    ...    ${ENGINEERING}${/}bin${/}Debug${/}net10.0${/}Engineering.dll
    IF    not ${has_workflow} or not ${built}
        Apply Challenge    ${PAGE2}    ${WORKSPACE}    ${SOLUTION_DIR}    ${MANIFEST_PAGE2}
        ...    rewrite_from=${VM_CHECKOUT}    rewrite_to=${TRACKS_SRC_DIR}
    END
    ${apphost}=    Get File    ${APPHOST}
    IF    'AddDaprComponent' not in $apphost
        Apply Challenge    ${PAGE3}    ${WORKSPACE}    ${SOLUTION_DIR}    ${NO_COPY_BLOCKS}
        ...    rewrite_from=${VM_CHECKOUT}    rewrite_to=${TRACKS_SRC_DIR}
    END
    # The page's own `aspire run` (section 1's restart), from the folder its `cd` names.
    ${aspire}=    Get Command Containing    ${ASSIGNMENT}    aspire run
    Start Aspire Run    ${aspire}    ${WORKSPACE}    ${LOG}
    Wait Until App Responds    ${APP_URL}    timeout=240s
    Wait Until Loopback Host Answers    ${DEV_DASHBOARD_URL}/api/workflows    localhost:9090
    # A fresh sandbox has no runs. Locally the Redis that `dapr init` started keeps the history of
    # earlier runs (dapr-workflow-101 uses the same app ID and run IDs), and a completed jump-002
    # would pass the check before this suite starts a run. Purge the page's IDs through the sidecar.
    FOR    ${id}    IN    jump-001    jump-002
        Run Process    dapr    workflow    purge    ${id}    --app-id    engineering    timeout=60s
    END
    FOR    ${id}    IN    jump-001    jump-002
        ${code}=    Capture Command Output    curl -s -o /dev/null -w '\%{http_code}' ${APP_URL}/status/${id}
        Should Be Equal    ${code}    404    msg=${id} is still in the state store after the purge
    END

Run Page Command
    # Run the page's command that contains ${needle}, from the workspace (the folder the page's
    # `cd` names), and return its output.
    [Arguments]    ${needle}
    ${command}=    Get Command Containing    ${ASSIGNMENT}    ${needle}
    ${r}=    Run Process    ${command}    shell=True    cwd=${WORKSPACE}    stderr=STDOUT    timeout=120s
    Should Be Equal As Integers    ${r.rc}    0    msg=${command} failed:\n${r.stdout}
    RETURN    ${r.stdout}

Run Status
    [Arguments]    ${id}
    ${out}=    Capture Command Output    curl -sf ${APP_URL}/status/${id}
    ${status}=    Evaluate    json.loads($out)    modules=json
    RETURN    ${status}

Run Should Be
    [Arguments]    ${id}    ${expected}
    ${status}=    Run Status    ${id}
    Should Be Equal    ${status}[status]    ${expected}

Wait Until Run Is
    [Arguments]    ${id}    ${expected}    ${timeout}=60s
    Wait Until Keyword Succeeds    ${timeout}    2s    Run Should Be    ${id}    ${expected}

Output Should Have The Page Shape
    # The readings and the priority are random: check the shape the page shows, and that the
    # bridge is notified exactly when the priority is Urgent.
    [Arguments]    ${output}    ${stardate}
    Should Be Equal    ${output}[starDate]    ${stardate}
    List Should Contain Value    ${PRIORITIES}    ${output}[priority]
    Should Match Regexp    ${output}[summary]
    ...    ^WarpCore=(Critical|Degraded|Nominal), LifeSupport=(Critical|Degraded|Nominal), Shields=(Critical|Degraded|Nominal)$
    Should Be Equal    ${output}[bridgeNotified]    ${{ $output["priority"] == "Urgent" }}
    ${keys}=    Evaluate    sorted($output)
    Should Be Equal    ${keys}    ${{ ["bridgeNotified", "priority", "starDate", "summary"] }}

History Of
    # The Dev Dashboard's view of one run (it reads the history from Redis, so it also answers while
    # engineering is stopped), as a dict: status, event types, the activities scheduled in order,
    # the times the diagnoses were scheduled, their results in order, when the timer fired (or
    # None), and how long the timer waited.
    [Arguments]    ${id}
    ${out}=    Capture Command Output
    ...    curl -sf -H 'Host: localhost:9090' ${DEV_DASHBOARD_URL}/api/workflows/engineering/${id}
    # One expression, built with Catenate: an Evaluate argument cannot span lines. t() reads an
    # event's time; the diagnoses' results are the TaskCompleted events whose scheduledId is the
    # sequenceId of a DiagnoseSubsystemActivity TaskScheduled event.
    ${expression}=    Catenate
    ...    (lambda d, t: (lambda h, diag: {
    ...    "status": d["status"],
    ...    "types": [e["type"] for e in h],
    ...    "scheduled": [e.get("name") for e in h if e["type"] == "TaskScheduled"],
    ...    "diagnose_times": [t(e) for e in h if e["type"] == "TaskScheduled" and e["sequenceId"] in diag],
    ...    "results": sorted(e.get("output") or "" for e in h if e["type"] == "TaskCompleted" and e.get("scheduledId") in diag),
    ...    "timer_fired": next((t(e) for e in h if e["type"] == "TimerFired"), None),
    ...    "timer_seconds": next(((t(f) - t(c)).total_seconds() for c in h if c["type"] == "TimerCreated" for f in h if f["type"] == "TimerFired"), 0),
    ...    })(d["history"], [e["sequenceId"] for e in d["history"] if e["type"] == "TaskScheduled" and e.get("name") == "DiagnoseSubsystemActivity"]))
    ...    (json.loads($out), lambda e: datetime.datetime.fromisoformat(e["timestamp"]))
    ${history}=    Evaluate    ${expression}    modules=json,datetime
    Log    ${history}
    RETURN    ${history}

Resource States
    # The state of each resource of the running AppHost, as `aspire describe` reports it.
    ${r}=    Run Process    aspire    describe    --apphost    ${APPHOST}    --format    Json
    ...    --non-interactive    --nologo    timeout=60s
    Should Be Equal As Integers    ${r.rc}    0    msg=aspire describe failed:\n${r.stdout}\n${r.stderr}
    ${states}=    Evaluate    {r["displayName"]: r["state"] for r in json.loads($r.stdout)["resources"]}    modules=json
    RETURN    ${states}

Run Completed Check
    ${check}=    Run Process    bash    ${CHECK_COMPLETED}    stderr=STDOUT    timeout=60s
    RETURN    ${check}

The Api Check Passes
    ${check}=    Run Process    bash    ${CHECK_API}    stderr=STDOUT    timeout=60s
    Should Be Equal As Integers    ${check.rc}    0    msg=check-api.sh failed:\n${check.stdout}

Assignment Should Contain
    [Arguments]    ${text}
    ${page}=    Get File    ${ASSIGNMENT}
    Should Contain    ${page}    ${text}    msg=page 4 does not show: ${text}

# doc-sync coverage: the suite runs each of these page commands from ${WORKSPACE} (the folder the
# page's `cd` names) with Run Page Command, and starts the page's `aspire run` in Suite Setup:
#   cd /root/university-labs/workflow-aspire
#   aspire run --apphost MeridianDiagnostics/apphost.cs
#   curl -s -X POST http://localhost:5411/start -H 'Content-Type: application/json' -d '{"id":"jump-001","starDate":"47634.4"}' | jq
#   curl -s http://localhost:5411/status/jump-001 | jq
#   curl -s -X POST http://localhost:5411/start -H 'Content-Type: application/json' -d '{"id":"jump-002","starDate":"47634.5"}' | jq
#   aspire resource engineering stop --apphost MeridianDiagnostics/apphost.cs
#   aspire resource engineering start --apphost MeridianDiagnostics/apphost.cs
#   curl -s http://localhost:5411/status/jump-002 | jq
