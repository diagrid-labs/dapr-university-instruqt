*** Settings ***
Name              Ch2 Task Chaining
Documentation     Drift test for dapr-workflow-101 page 2: demo 2 runs `engineering`, whose `JumpWorkflow`
...               chains four activities (plot course, charge warp core, align nav array, engage jump),
...               passing each result to the next. The suite starts `jump-001` to Vesper Reach and checks
...               the four log lines and the COMPLETED output, then starts `jump-002` to Calder Station
...               and checks that it travels down the same chain. Finally it reuses the ID of a jump that
...               is still running and expects `500 WORKFLOW_ERROR`.
...
...               The stardate comes from the clock, and a whole number may lose its `.0` per language,
...               so the suite asserts `"arrivedAt":"Vesper Reach"` and not the stardate.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - engineering ==` and, in .NET, Python and Java, a logger prefix too, so only
...               the message is matched. The TypeScript SDK logs extra lines of its own; none of them
...               contains the messages matched here.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-workflow-101-ch2.log
# The page's expected outputs, as compact JSON; jq prints them formatted.
${STARTED_1}        {"jumpId":"jump-001"}
${STARTED_2}        {"jumpId":"jump-002"}
${STARTED_3}        {"jumpId":"jump-003"}
${ERROR}            {"error":"WORKFLOW_ERROR"}

*** Test Cases ***
Ports Are Free Before The App Starts
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5301    3530    50330
        Port Should Be Free    ${port}
    END

DotNet Chain Of Four Activities
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    dotnet build    ${WF101_BASE}/${DEMO2}[dotnet]/Engineering
    Walk Through Task Chaining    dotnet

Python Chain Of Four Activities
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    uv sync    ${WF101_BASE}/${DEMO2}[python]/engineering
    Walk Through Task Chaining    python

Java Chain Of Four Activities
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    mvn -q -DskipTests package    ${WF101_BASE}/${DEMO2}[java]/engineering
    Walk Through Task Chaining    java    timeout=300s

TypeScript Chain Of Four Activities
    [Tags]    typescript
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    # `npm start` runs app.ts with tsx from node_modules, which CI (and the sandbox's pre-build)
    # installs with `npm ci` before this suite runs.
    Directory Should Exist    ${WF101_BASE}/${DEMO2}[typescript]/engineering/node_modules
    Walk Through Task Chaining    typescript

*** Keywords ***
Port Should Be Free
    [Arguments]    ${port}
    # curl exits 7 (connection refused) only when nothing listens. Anything else, an HTTP answer
    # (rc 0) or a gRPC server that doesn't speak HTTP/1.1 (another rc), means the port is taken.
    ${result}=    Run Process    curl -s -o /dev/null --max-time 2 http://localhost:${port}/    shell=True
    Should Be Equal As Integers    ${result.rc}    7
    ...    msg=Something is already listening on port ${port}. Stop the leaked app before running this suite.

Wait For The Ports To Be Free
    # The previous app can take a moment to release the ports after SIGINT. Without this, a
    # readiness probe could be answered by the previous app, or the next sidecar fails to bind.
    FOR    ${port}    IN    5301    3530    50330
        Wait Until Keyword Succeeds    30s    1s    Port Should Be Free    ${port}
    END

Clean Up And Stop
    # The page's clean-up, run while the app still runs. The test body already ran it and checked
    # it; this repeat only matters when the test failed before that point, so its result is ignored.
    # A jump that a failed test left running is terminated first, so the purge can remove it.
    Terminate Running Jumps
    Run Process    dapr workflow purge --all -a engineering    shell=True
    Stop Process With SIGINT If Running    app

Terminate Running Jumps
    # Terminate every jump that is still running, so a test that failed half-way doesn't leave one
    # in the shared Redis for the next suite. `dapr workflow list` can't combine `-s` with `-o ids`,
    # so read the JSON list; with no workflows at all it prints a message instead of JSON.
    ${list}=    Run Process    dapr workflow list -a engineering -o json    shell=True    stderr=STDOUT
    IF    ${list.rc} != 0 or not $list.stdout.strip().startswith('[')    RETURN
    ${ids}=    Evaluate
    ...    [w['instanceID'] for w in json.loads($list.stdout) if w['runtimeStatus'] in ('RUNNING', 'SUSPENDED')]
    ...    modules=json
    FOR    ${id}    IN    @{ids}
        Log    Clean-up: terminating ${id}    WARN
        Run Process    dapr workflow terminate ${id} -a engineering    shell=True
    END
    # Terminate is asynchronous and purge only removes finished jumps, so wait until none runs.
    IF    ${ids}
        Run Keyword And Warn On Failure
        ...    Wait Until Keyword Succeeds    20s    2s    No Jump Should Be Running
    END

No Jump Should Be Running
    ${list}=    Run Process    dapr workflow list -a engineering -s RUNNING    shell=True    stderr=STDOUT
    Should Contain    ${list.stdout}    No workflow found

Walk Through Task Chaining
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${WF101_BASE}/${DEMO2}[${lang}]

    # 2. Run the demo.
    Start Background Process    exec dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    ${APP_URL}/    ${timeout}

    # 3. Start jump-001: four log lines, about a second apart, then COMPLETED.
    Assert Pretty JSON Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001", "destination": "Vesper Reach"}' | jq
    ...    ${STARTED_1}
    Wait Until Log Contains    ${LOG}    engineering course plotted to Vesper Reach heading=217 distanceLy=4.2    60s
    Wait Until Log Contains    ${LOG}    engineering warp core charged to warp 6    60s
    Wait Until Log Contains    ${LOG}    engineering nav array aligned    60s
    Wait Until Log Contains    ${LOG}    engineering jump complete, arrived at Vesper Reach    60s
    # The stardate comes from the clock and may lose its `.0`, so only the destination is asserted.
    Wait Until Keyword Succeeds    30s    1s    Jump Should Be Completed At    jump-001    Vesper Reach

    # 4. Another destination travels down the same chain.
    Assert Pretty JSON Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002", "destination": "Calder Station"}' | jq
    ...    ${STARTED_2}
    Wait Until Log Contains    ${LOG}    engineering course plotted to Calder Station heading=217 distanceLy=4.2    60s
    Wait Until Log Contains    ${LOG}    engineering jump complete, arrived at Calder Station    60s
    Wait Until Keyword Succeeds    30s    1s    Jump Should Be Completed At    jump-002    Calder Station

    # 5. Reuse the ID of a running jump. The page uses jump-003; the suite runs it as a unique
    # variant so a leftover jump-003 from an earlier run can't make the first start fail.
    ${id}=    Evaluate    "jump-003-" + uuid.uuid4().hex[:8]    modules=uuid
    Assert Pretty JSON Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "${id}"}' | jq
    ...    {"jumpId":"${id}"}
    Assert Pretty JSON Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "${id}"}' | jq
    ...    ${ERROR}
    Wait Until Log Contains    ${LOG}    engineering workflow call failed:    30s
    # Once it has completed, the same call starts the jump over.
    Wait Until Keyword Succeeds    30s    1s    Jump Should Be Completed At    ${id}    Vesper Reach

    # 6. Clean up, while the app still runs.
    Run And Expect RC Zero    dapr workflow purge --all -a engineering
    ${gone}=    Capture Command Output    curl -s -o /dev/null -w '\%{http_code}' http://localhost:5301/jumps/jump-001
    Should Be Equal    ${gone}    404

Jump Should Be Completed At
    [Arguments]    ${jump_id}    ${destination}
    ${out}=    Capture Command Output    curl -s http://localhost:5301/jumps/${jump_id} | jq -c
    Should Contain    ${out}    "status":"COMPLETED"
    Should Contain    ${out}    "arrivedAt":"${destination}"

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder; the status checks go through `Jump Should Be Completed At`, and the
# page's `jump-003` is run as `jump-003-<random>` so a re-run is safe):
#   cd /root/university-labs/workflow
#   cd dotnet/Demo2-TaskChaining
#   cd python/demo2-task-chaining
#   cd java/demo2-task-chaining
#   cd typescript/demo2-task-chaining
#   dapr run -f .
#   curl -s http://localhost:5301/jumps/jump-001 | jq
#   curl -s http://localhost:5301/jumps/jump-002 | jq
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-003"}' | jq
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-003"}' | jq
