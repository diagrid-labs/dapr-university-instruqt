*** Settings ***
Name              Ch3 Fan-out Fan-in
Documentation     Drift test for dapr-workflow-101 page 3: demo 3 runs `engineering`, whose
...               `RouteScanWorkflow` scans the route with five sensor arrays at the same time
...               (fan-out) and combines the results (fan-in): `routeRisk` is the highest hazard,
...               and the verdict is CLEAR below 50. The suite starts `jump-001` and `jump-002`, and
...               checks the five scan lines and the COMPLETED output of each.
...
...               The scans finish in a different order from run to run, so the suite asserts that all
...               five lines are logged and never their order. The page's start-sleep-status block
...               checks the jump after 4 seconds: five scans in a row take 10, so a COMPLETED
...               status after 4 shows they ran in parallel.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - engineering ==` and, in .NET, Python and Java, a logger prefix too, so only
...               the message is matched.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-workflow-101-ch3.log
# The page's expected outputs, as compact JSON; jq prints them formatted.
${STARTED_1}        {"jumpId":"jump-001"}
${STARTED_2}        {"jumpId":"jump-002"}
${COMPLETED_1}      {"jumpId":"jump-001","status":"COMPLETED","output":{"routeRisk":31,"verdict":"CLEAR"}}
${COMPLETED_2}      {"jumpId":"jump-002","status":"COMPLETED","output":{"routeRisk":31,"verdict":"CLEAR"}}

*** Test Cases ***
Ports Are Free Before The App Starts
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5301    3530    50330
        Port Should Be Free    ${port}
    END

DotNet Five Scans At Once
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    dotnet build    ${WF101_BASE}/${DEMO3}[dotnet]/Engineering
    Walk Through Fan Out Fan In    dotnet

Python Five Scans At Once
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    uv sync    ${WF101_BASE}/${DEMO3}[python]/engineering
    Walk Through Fan Out Fan In    python

Java Five Scans At Once
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    mvn -q -DskipTests package    ${WF101_BASE}/${DEMO3}[java]/engineering
    Walk Through Fan Out Fan In    java    timeout=300s

TypeScript Five Scans At Once
    [Tags]    typescript
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    # `npm start` runs app.ts with tsx from node_modules, which CI (and the sandbox's pre-build)
    # installs with `npm ci` before this suite runs.
    Directory Should Exist    ${WF101_BASE}/${DEMO3}[typescript]/engineering/node_modules
    Walk Through Fan Out Fan In    typescript

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
    Run Process    dapr workflow purge --all -a engineering    shell=True
    Stop Process With SIGINT    app

Walk Through Fan Out Fan In
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${WF101_BASE}/${DEMO3}[${lang}]

    # 2. Run the demo.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    ${APP_URL}/    ${timeout}

    # 3. Start a jump, wait 4 seconds and read the status, all in one block as on the page.
    # Five scans of 2 seconds in a row would take 10 seconds, so COMPLETED after 4 shows that
    # they ran at the same time.
    ${out}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq; sleep 4; curl -s http://localhost:5301/jumps/jump-001 | jq
    ${started}=    Pretty Json    ${STARTED_1}
    ${completed}=    Pretty Json    ${COMPLETED_1}
    Should Be Equal    ${out}    ${started}\n${completed}
    Five Scans Should Be Logged

    # 4. A second jump: the log order may differ, the result doesn't.
    ${out}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002"}' | jq; sleep 4; curl -s http://localhost:5301/jumps/jump-002 | jq
    ${started}=    Pretty Json    ${STARTED_2}
    ${completed}=    Pretty Json    ${COMPLETED_2}
    Should Be Equal    ${out}    ${started}\n${completed}
    Count In File Should Be    ${LOG}    engineering sensor array gamma scanned hazard=31    2

    # 5. Clean up, while the app still runs.
    Run And Expect RC Zero    dapr workflow purge --all -a engineering
    ${gone}=    Capture Command Output    curl -s -o /dev/null -w '\%{http_code}' http://localhost:5301/jumps/jump-001
    Should Be Equal    ${gone}    404

Five Scans Should Be Logged
    # All five lines, in any order.
    Wait Until Log Contains    ${LOG}    engineering sensor array alpha scanned hazard=12    30s
    Wait Until Log Contains    ${LOG}    engineering sensor array beta scanned hazard=7    30s
    Wait Until Log Contains    ${LOG}    engineering sensor array gamma scanned hazard=31    30s
    Wait Until Log Contains    ${LOG}    engineering sensor array delta scanned hazard=4    30s
    Wait Until Log Contains    ${LOG}    engineering sensor array epsilon scanned hazard=18    30s

Count In File Should Be
    [Arguments]    ${file}    ${text}    ${expected}
    ${content}=    Get File    ${file}
    ${count}=    Get Count    ${content}    ${text}
    Should Be Equal As Integers    ${count}    ${expected}

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder; the start, sleep and status commands run as one block, as on the page):
#   cd /root/university-labs/workflow
#   cd dotnet/Demo3-FanOutFanIn
#   cd python/demo3-fan-out-fan-in
#   cd java/demo3-fan-out-fan-in
#   cd typescript/demo3-fan-out-fan-in
#   dapr run -f .
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq
#   sleep 4
#   curl -s http://localhost:5301/jumps/jump-001 | jq
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002"}' | jq
#   sleep 4
#   curl -s http://localhost:5301/jumps/jump-002 | jq
