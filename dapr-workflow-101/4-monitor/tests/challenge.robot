*** Settings ***
Name              Ch4 Monitor
Documentation     Drift test for dapr-workflow-101 page 4: demo 4 runs `engineering`, whose
...               `CoreStabilityWorkflow` reads the core temperature, and until it is 1000K or lower
...               waits on a durable timer of 5 seconds and continues as new with the next check
...               number. The suite starts `jump-001`, checks the status is RUNNING while the monitor
...               waits, the five check lines and the COMPLETED output. The instance ID stays
...               `jump-001` across continue-as-new, so one status URL serves the whole run.
...
...               Five checks, 5 seconds apart, take about 20 seconds. The suite waits for the last
...               check line and then polls the status, with generous margins.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - engineering ==` and, in .NET, Python and Java, a logger prefix too, so only
...               the message is matched.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-workflow-101-ch4.log
# The page's expected outputs, as compact JSON; jq prints them formatted.
${STARTED_1}        {"jumpId":"jump-001"}
${RUNNING_1}        {"jumpId":"jump-001","status":"RUNNING","output":null}
${COMPLETED_1}      {"jumpId":"jump-001","status":"COMPLETED","output":{"stable":true,"checks":5,"coreTempK":1000}}
${STATUS_1}         curl -s http://localhost:5301/jumps/jump-001 | jq

*** Test Cases ***
Ports Are Free Before The App Starts
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5301    3530    50330
        Port Should Be Free    ${port}
    END

DotNet Monitor Until Stable
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    dotnet build    ${WF101_BASE}/${DEMO4}[dotnet]/Engineering
    Walk Through Monitor    dotnet

Python Monitor Until Stable
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    uv sync    ${WF101_BASE}/${DEMO4}[python]/engineering
    Walk Through Monitor    python

Java Monitor Until Stable
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    mvn -q -DskipTests package    ${WF101_BASE}/${DEMO4}[java]/engineering
    Walk Through Monitor    java    timeout=300s

TypeScript Monitor Until Stable
    [Tags]    typescript
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Directory Should Exist    ${WF101_BASE}/${DEMO4}[typescript]/engineering/node_modules
    Walk Through Monitor    typescript

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
    Stop Process With SIGINT    app

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

Walk Through Monitor
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${WF101_BASE}/${DEMO4}[${lang}]

    # 2. Run the demo.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    ${APP_URL}/    ${timeout}

    # 3. Start a jump, wait 7 seconds and read the status, all in one block as on the page.
    # Check 2 is logged at about 5 seconds and the monitor runs for about 20, so the status is RUNNING.
    ${out}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq; sleep 7; ${STATUS_1}
    ${started}=    Pretty Json    ${STARTED_1}
    ${running}=    Pretty Json    ${RUNNING_1}
    Should Be Equal    ${out}    ${started}\n${running}

    # 4. The five checks, one about every 5 seconds, each exactly once.
    Wait Until Log Contains    ${LOG}    engineering core temperature check 5: 1000K    90s
    Wait Until Log Contains    ${LOG}    engineering core temperature check 1: 1240K    5s
    Wait Until Log Contains    ${LOG}    engineering core temperature check 2: 1180K    5s
    Wait Until Log Contains    ${LOG}    engineering core temperature check 3: 1120K    5s
    Wait Until Log Contains    ${LOG}    engineering core temperature check 4: 1060K    5s
    Count In File Should Be    ${LOG}    engineering core temperature check 1: 1240K    1
    Count In File Should Be    ${LOG}    engineering core temperature check 5: 1000K    1

    # 5. The status command as on the page, run until it says COMPLETED (the last check is done,
    # but the workflow may still be completing).
    ${completed}=    Pretty Json    ${COMPLETED_1}
    Wait Until Keyword Succeeds    60s    2s    Status Should Be    ${completed}

    # 6. Clean up, while the app still runs.
    Run And Expect RC Zero    dapr workflow purge --all -a engineering
    ${gone}=    Capture Command Output    curl -s -o /dev/null -w '\%{http_code}' http://localhost:5301/jumps/jump-001
    Should Be Equal    ${gone}    404

Status Should Be
    [Arguments]    ${expected}
    ${out}=    Capture Command Output    ${STATUS_1}
    Should Be Equal    ${out}    ${expected}

Count In File Should Be
    [Arguments]    ${file}    ${text}    ${expected}
    ${content}=    Get File    ${file}
    ${count}=    Get Count    ${content}    ${text}
    Should Be Equal As Integers    ${count}    ${expected}

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder; the start, sleep and status commands run as one block, as on the page):
#   cd /root/university-labs/workflow
#   cd dotnet/Demo4-Monitor
#   cd python/demo4-monitor
#   cd java/demo4-monitor
#   cd typescript/demo4-monitor
#   dapr run -f .
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq
#   sleep 7
#   curl -s http://localhost:5301/jumps/jump-001 | jq
