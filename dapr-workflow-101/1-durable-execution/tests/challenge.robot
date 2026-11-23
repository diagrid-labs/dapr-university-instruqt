*** Settings ***
Name              Ch1 Durable Execution
Documentation     Drift test for dapr-workflow-101 page 1: demo 1 runs `engineering`, whose
...               `ChargeWarpCoreWorkflow` calls `ChargeStageActivity` five times in a loop. The suite
...               starts `jump-001`, stops the whole `dapr run` tree right after stage 2 (the learner's
...               Ctrl+C), starts the demo again with a second log file and checks that the workflow
...               carries on by itself: stages 3 to 5 complete, stages 1 and 2 don't run again, and the
...               replay-safe `charge sequence started` line is not logged a second time. Then the jump
...               is COMPLETED, the page's fallback `jump-002` runs to the end, and both are purged.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - engineering ==` and, in .NET, Python and Java, a logger prefix too, so only
...               the message is matched. The TypeScript SDK logs extra lines of its own; none of them
...               contains the messages matched here.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-workflow-101-ch1.log
${RESTART_LOG}      ${TEMPDIR}/dapr-workflow-101-ch1-restart.log
# `exec` makes the shell that Robot starts become `dapr run` itself, as the learner's terminal runs
# it in the foreground process group that Ctrl+C reaches. Without it, Linux's /bin/sh (dash) forks
# `dapr run` as a child, `dapr run -f` moves itself into a new process group at startup, and the
# SIGINT that `Stop Process With SIGINT` sends to the shell's group never reaches it: the app keeps
# running until the tree-kill fallback 15 s later and finishes stages 3 to 5 before the "crash".
# macOS's /bin/sh (bash) already execs a single command, which is why this only failed in CI.
${DAPR_RUN}         exec dapr run -f .
# What the dapr CLI prints when it gets the SIGINT, i.e. the learner's Ctrl+C path.
${STOPPING}         Received signal to stop Dapr and app processes
# The workflow's replay-safe log line (ChargeWarpCoreWorkflow in every language).
${STARTED}          engineering jump-001 charge sequence started
# The page's expected outputs, as compact JSON; jq prints them formatted.
${STARTED_1}        {"jumpId":"jump-001"}
${COMPLETED_1}      {"jumpId":"jump-001","status":"COMPLETED","output":{"jumpId":"jump-001","coreCharged":true}}
${STARTED_2}        {"jumpId":"jump-002"}
${COMPLETED_2}      {"jumpId":"jump-002","status":"COMPLETED","output":{"jumpId":"jump-002","coreCharged":true}}

*** Test Cases ***
Ports Are Free Before The App Starts
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5301    3530    50330
        Port Should Be Free    ${port}
    END

DotNet Workflow Survives A Crash
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    dotnet build    ${WF101_BASE}/${DEMO1}[dotnet]/Engineering
    Walk Through Durable Execution    dotnet

Python Workflow Survives A Crash
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    uv sync    ${WF101_BASE}/${DEMO1}[python]/engineering
    Walk Through Durable Execution    python

Java Workflow Survives A Crash
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    mvn -q -DskipTests package    ${WF101_BASE}/${DEMO1}[java]/engineering
    Walk Through Durable Execution    java    timeout=300s

TypeScript Workflow Survives A Crash
    [Tags]    typescript
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    # `npm start` runs app.ts with tsx from node_modules, which CI (and the sandbox's pre-build)
    # installs with `npm ci` before this suite runs.
    Directory Should Exist    ${WF101_BASE}/${DEMO1}[typescript]/engineering/node_modules
    Walk Through Durable Execution    typescript

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

Count In File
    [Arguments]    ${file}    ${text}
    ${content}=    Get File    ${file}
    ${count}=    Get Count    ${content}    ${text}
    RETURN    ${count}

Count In File Should Be
    [Arguments]    ${file}    ${text}    ${expected}
    ${count}=    Count In File    ${file}    ${text}
    Should Be Equal As Integers    ${count}    ${expected}
    ...    msg=Expected "${text}" ${expected} time(s) in ${file}, found ${count}.

Clean Up And Stop
    # The page's clean-up, run while the app still runs. The test body already ran it and checked
    # it; this repeat only matters when the test failed before that point, so its result is ignored.
    # A jump that a failed test left running is terminated first, so the purge can remove it.
    Terminate Running Jumps
    Run Process    dapr workflow purge jump-001 -a engineering    shell=True
    Run Process    dapr workflow purge jump-002 -a engineering    shell=True
    # A test that failed after the first stop and before the restart has no app left to stop.
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

Walk Through Durable Execution
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${WF101_BASE}/${DEMO1}[${lang}]

    # 3. Run the demo.
    Start Background Process    ${DAPR_RUN}    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    ${APP_URL}/    ${timeout}

    # 4. Start jump-001 and crash the ship right after stage 2. The log is polled quickly so the
    # stop lands while stage 3 (3 s) is still running, as on the page. The 1 s pause stands for the
    # learner's reaction time: an activity logs its line just before it reports its result, and a
    # stop within milliseconds of the line (seen with Java) can make stage 2 run again, as
    # at-least-once allows, which no learner is fast enough to see.
    Assert Pretty JSON Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq
    ...    ${STARTED_1}
    Wait Until Log Contains    ${LOG}    ${STARTED}    60s
    Wait Until Keyword Succeeds    60s    0.2s
    ...    File Should Contain    ${LOG}    engineering charge stage 2/5 complete for jump-001
    Sleep    1s
    Stop Process With SIGINT    app
    # The dapr CLI got the SIGINT and stopped the app itself, as on a Ctrl+C, rather than the
    # keyword's tree-kill fallback stopping it after its 15 s timeout.
    File Should Contain    ${LOG}    ${STOPPING}
    Count In File Should Be    ${LOG}    engineering charge stage 1/5 complete for jump-001    1
    Count In File Should Be    ${LOG}    engineering charge stage 4/5 complete for jump-001    0
    Count In File Should Be    ${LOG}    engineering charge stage 5/5 complete for jump-001    0
    Wait For The Ports To Be Free

    # 5. Start the demo again, with no new curl: the workflow carries on by itself.
    Start Background Process    ${DAPR_RUN}    ${RESTART_LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    ${APP_URL}/    ${timeout}
    Wait Until Log Contains    ${RESTART_LOG}    engineering charge stage 5/5 complete for jump-001    120s
    File Should Contain    ${RESTART_LOG}    engineering charge stage 3/5 complete for jump-001
    File Should Contain    ${RESTART_LOG}    engineering charge stage 4/5 complete for jump-001
    # Completed stages are not repeated, and the replay doesn't log the replay-safe line again.
    Count In File Should Be    ${RESTART_LOG}    engineering charge stage 1/5 complete for jump-001    0
    Count In File Should Be    ${RESTART_LOG}    engineering charge stage 2/5 complete for jump-001    0
    Count In File Should Be    ${RESTART_LOG}    charge sequence started    0
    Wait Until Keyword Succeeds    30s    1s    Assert Pretty JSON Output
    ...    curl -s http://localhost:5301/jumps/jump-001 | jq
    ...    ${COMPLETED_1}

    # The page's fallback when the learner misses the moment: the same curl with a new ID.
    Assert Pretty JSON Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002"}' | jq
    ...    ${STARTED_2}
    Wait Until Keyword Succeeds    60s    2s    Assert Pretty JSON Output
    ...    curl -s http://localhost:5301/jumps/jump-002 | jq
    ...    ${COMPLETED_2}

    # 6. Clean up, while the app still runs.
    Run And Expect RC Zero    dapr workflow purge jump-001 -a engineering
    Run And Expect RC Zero    dapr workflow purge jump-002 -a engineering
    ${gone}=    Capture Command Output    curl -s -o /dev/null -w '\%{http_code}' http://localhost:5301/jumps/jump-001
    Should Be Equal    ${gone}    404

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder):
#   cd /root/university-labs/workflow
#   cd dotnet/Demo1-DurableExecution
#   cd python/demo1-durable-execution
#   cd java/demo1-durable-execution
#   cd typescript/demo1-durable-execution
#   dapr run -f .
