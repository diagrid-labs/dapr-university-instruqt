*** Settings ***
Name              Ch6 Workflow Management
Documentation     Drift test for dapr-workflow-101 page 6: demo 6 runs `engineering`, whose
...               `LongRangeJumpWorkflow` has 10 legs. Each leg is one call to `EngageLegActivity`,
...               which logs `engineering <jumpId> leg <n>/10 complete`, followed by a 5-second
...               durable timer. The app adds four endpoints, each one call on the SDK's workflow
...               client: pause, resume, terminate and purge (DELETE).
...
...               The suite pauses `jump-001` and checks that no legs follow, tries to purge it while
...               it is paused (500 WORKFLOW_ERROR, still SUSPENDED), resumes it and checks that the
...               next leg follows and that it completes. It terminates `jump-002`, checks the 409 on
...               a finished jump and the 404 on an unknown one, and purges `jump-002` (204, then
...               404). It then manages `jump-003` with the `dapr workflow` CLI: list, suspend,
...               resume, terminate and purge.
...
...               The page's clean-up terminates a jump that is still RUNNING or SUSPENDED before it
...               purges. After the page's steps none is, so the suite starts `jump-004` and pauses
...               it, so the list and terminate commands have a suspended jump to act on.
...
...               Pause, resume and terminate act asynchronously. The page checks the status two
...               seconds later and tells the learner to run the status command again if it hasn't
...               changed yet; the suite accepts the old status in the block and then polls.
...
...               The control calls print the HTTP status after the body, through the page's
...               `curl -s -w ' %{http_code}\n' <url> | jq`: jq reads the body and then the status as a
...               second JSON value. The 202 and 204 have no body, so only the status is printed.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - engineering ==` and, in .NET, Python and Java, a logger prefix too, so only
...               the message is matched.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-workflow-101-ch6.log
# The page's expected outputs, as compact JSON; jq prints them formatted.
${STARTED_1}        {"jumpId":"jump-001"}
${STARTED_2}        {"jumpId":"jump-002"}
${STARTED_3}        {"jumpId":"jump-003"}
${STARTED_4}        {"jumpId":"jump-004"}
${RUNNING_1}        {"jumpId":"jump-001","status":"RUNNING","output":null}
${SUSPENDED_1}      {"jumpId":"jump-001","status":"SUSPENDED","output":null}
${COMPLETED_1}      {"jumpId":"jump-001","status":"COMPLETED","output":{"status":"JUMPED","arrivedAt":"Vesper Reach"}}
${RUNNING_2}        {"jumpId":"jump-002","status":"RUNNING","output":null}
${TERMINATED_2}     {"jumpId":"jump-002","status":"TERMINATED","output":null}
${RUNNING_3}        {"jumpId":"jump-003","status":"RUNNING","output":null}
${SUSPENDED_3}      {"jumpId":"jump-003","status":"SUSPENDED","output":null}
${TERMINATED_3}     {"jumpId":"jump-003","status":"TERMINATED","output":null}
${WORKFLOW_ERROR}   {"error":"WORKFLOW_ERROR"}
${FINISHED}         {"error":"JUMP_FINISHED"}
${NOT_FOUND}        {"error":"JUMP_NOT_FOUND"}
${START_1}          curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq
${START_2}          curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002"}' | jq
${START_3}          curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-003"}' | jq
${START_4}          curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-004"}' | jq
${STATUS_1}         curl -s http://localhost:5301/jumps/jump-001 | jq
${STATUS_2}         curl -s http://localhost:5301/jumps/jump-002 | jq
${STATUS_3}         curl -s http://localhost:5301/jumps/jump-003 | jq
${PAUSE_1}          curl -s -w ' \%{http_code}\\n' -X POST http://localhost:5301/jumps/jump-001/pause | jq
${RESUME_1}         curl -s -w ' \%{http_code}\\n' -X POST http://localhost:5301/jumps/jump-001/resume | jq
${PURGE_1}          curl -s -w ' \%{http_code}\\n' -X DELETE http://localhost:5301/jumps/jump-001 | jq
${TERMINATE_2}      curl -s -w ' \%{http_code}\\n' -X POST http://localhost:5301/jumps/jump-002/terminate | jq
${PAUSE_2}          curl -s -w ' \%{http_code}\\n' -X POST http://localhost:5301/jumps/jump-002/pause | jq
${PAUSE_999}        curl -s -w ' \%{http_code}\\n' -X POST http://localhost:5301/jumps/jump-999/pause | jq
${PURGE_2}          curl -s -w ' \%{http_code}\\n' -X DELETE http://localhost:5301/jumps/jump-002 | jq
${GET_2}            curl -s -w ' \%{http_code}\\n' http://localhost:5301/jumps/jump-002 | jq
${PAUSE_4}          curl -s -w ' \%{http_code}\\n' -X POST http://localhost:5301/jumps/jump-004/pause | jq

*** Test Cases ***
Ports Are Free Before The App Starts
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5301    3530    50330
        Port Should Be Free    ${port}
    END

DotNet Pause Resume Terminate And Purge
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    dotnet build    ${WF101_BASE}/${DEMO6}[dotnet]/Engineering
    Walk Through Management    dotnet

Python Pause Resume Terminate And Purge
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    uv sync    ${WF101_BASE}/${DEMO6}[python]/engineering
    Walk Through Management    python

Java Pause Resume Terminate And Purge
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    mvn -q -DskipTests package    ${WF101_BASE}/${DEMO6}[java]/engineering
    Walk Through Management    java    timeout=300s

TypeScript Pause Resume Terminate And Purge
    [Tags]    typescript
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Directory Should Exist    ${WF101_BASE}/${DEMO6}[typescript]/engineering/node_modules
    Walk Through Management    typescript

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
    # The page's clean-up, run while the app still runs: terminate every jump that is still
    # running or suspended, then purge. The test body already ran it and checked it; this repeat
    # matters when the test failed before that point and left a jump in the shared Redis. A
    # failure here doesn't fail the teardown, but it is logged as a warning so it shows in the report.
    Terminate Running Jumps
    ${purge}=    Run Process    dapr workflow purge --all -a engineering    shell=True    stderr=STDOUT
    IF    ${purge.rc} != 0
        Log    Clean-up: purge failed (rc=${purge.rc}): ${purge.stdout}    WARN
    END
    Stop Process With SIGINT If Running    app

Unfinished Jump IDs
    # `dapr workflow list` can't combine a status filter with `-o ids`, so read the JSON list and
    # pick the jumps whose runtimeStatus is RUNNING or SUSPENDED. With no workflows at all, the CLI
    # prints a "No workflow found" message instead of JSON, and there is nothing to terminate.
    ${list}=    Run Process    dapr workflow list -a engineering -o json    shell=True    stderr=STDOUT
    IF    ${list.rc} != 0
        Fail    dapr workflow list failed (rc=${list.rc}): ${list.stdout}
    END
    IF    not $list.stdout.strip().startswith('[')
        ${none}=    Create List
        RETURN    ${none}
    END
    ${ids}=    Evaluate
    ...    [w['instanceID'] for w in json.loads($list.stdout) if w['runtimeStatus'] in ('RUNNING', 'SUSPENDED')]
    ...    modules=json
    RETURN    ${ids}

Terminate Running Jumps
    ${status}    ${ids}=    Run Keyword And Ignore Error    Unfinished Jump IDs
    IF    '${status}' == 'FAIL'
        Log    Clean-up: ${ids}    WARN
        RETURN
    END
    FOR    ${id}    IN    @{ids}
        ${r}=    Run Process    dapr workflow terminate ${id} -a engineering    shell=True    stderr=STDOUT
        IF    ${r.rc} != 0
            Log    Clean-up: terminate ${id} failed (rc=${r.rc}): ${r.stdout}    WARN
        ELSE
            Log    Clean-up: terminated ${id}
        END
    END
    # Terminate is asynchronous and purge only removes finished jumps, so wait until none runs.
    IF    ${ids}
        Run Keyword And Warn On Failure
        ...    Wait Until Keyword Succeeds    20s    2s    No Jump Should Be Unfinished
    END

No Jump Should Be Unfinished
    ${ids}=    Unfinished Jump IDs
    Should Be Empty    ${ids}

Status Should Be
    [Arguments]    ${command}    ${expected}
    ${out}=    Capture Command Output    ${command}
    Should Be Equal    ${out}    ${expected}

Block Should Show New Or Old Status
    # A block that ends with a status read after an asynchronous control call: the head of the
    # output is fixed, the status at the end is the new one or, on a slow run, still the old one.
    [Arguments]    ${out}    ${head}    ${new}    ${old}
    Should Start With    ${out}    ${head}
    ${status}=    Get Substring    ${out}    ${{len($head)}}
    Should Be True    $status in ($new, $old)    msg=Unexpected status at the end of the block:\n${status}

Leg Count
    [Arguments]    ${jump}
    ${content}=    Get File    ${LOG}
    ${count}=    Get Count    ${content}    engineering ${jump} leg
    RETURN    ${count}

Settled Leg Count
    # The leg count once it has stopped changing for 3 seconds. A leg activity that was already
    # running when the jump was paused or terminated may still log after that.
    [Arguments]    ${jump}
    ${after}=    Leg Count    ${jump}
    FOR    ${i}    IN RANGE    10
        Sleep    3s
        ${before}=    Set Variable    ${after}
        ${after}=    Leg Count    ${jump}
        IF    ${before} == ${after}    RETURN    ${after}
    END
    Fail    The leg count of ${jump} kept changing

Count In File Should Be
    [Arguments]    ${file}    ${text}    ${expected}
    ${content}=    Get File    ${file}
    ${count}=    Get Count    ${content}    ${text}
    Should Be Equal As Integers    ${count}    ${expected}

Walk Through Management
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${WF101_BASE}/${DEMO6}[${lang}]
    ${started_1}=    Pretty Json    ${STARTED_1}
    ${started_2}=    Pretty Json    ${STARTED_2}
    ${started_3}=    Pretty Json    ${STARTED_3}
    ${started_4}=    Pretty Json    ${STARTED_4}
    ${running_1}=    Pretty Json    ${RUNNING_1}
    ${suspended_1}=    Pretty Json    ${SUSPENDED_1}
    ${completed_1}=    Pretty Json    ${COMPLETED_1}
    ${running_2}=    Pretty Json    ${RUNNING_2}
    ${terminated_2}=    Pretty Json    ${TERMINATED_2}
    ${running_3}=    Pretty Json    ${RUNNING_3}
    ${suspended_3}=    Pretty Json    ${SUSPENDED_3}
    ${terminated_3}=    Pretty Json    ${TERMINATED_3}
    ${workflow_error}=    Pretty Json    ${WORKFLOW_ERROR}
    ${finished}=    Pretty Json    ${FINISHED}
    ${not_found}=    Pretty Json    ${NOT_FOUND}

    # 2. Run the demo.
    Start Background Process    exec dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    ${APP_URL}/    ${timeout}

    # 3. Start jump-001, wait 8 seconds, pause it, wait 2 seconds and read the status, in one block
    # as on the page. Legs 1 and 2 are logged by then.
    ${out}=    Capture Command Output    ${START_1}; sleep 8; ${PAUSE_1}; sleep 2; ${STATUS_1}
    Block Should Show New Or Old Status    ${out}    ${started_1}\n202\n    ${suspended_1}    ${running_1}
    Wait Until Keyword Succeeds    20s    2s    Status Should Be    ${STATUS_1}    ${suspended_1}
    Wait Until Log Contains    ${LOG}    engineering jump-001 leg 1/10 complete    5s
    # No legs while the jump is paused.
    ${paused_at}=    Settled Leg Count    jump-001
    Sleep    12s
    ${now}=    Leg Count    jump-001
    Should Be Equal As Integers    ${now}    ${paused_at}    msg=A leg was logged while jump-001 was paused

    # 4. Purge the paused jump: 500, a warning in the log, and the jump is still SUSPENDED.
    ${out}=    Capture Command Output    ${PURGE_1}
    Should Be Equal    ${out}    ${workflow_error}\n500
    Wait Until Log Contains    ${LOG}    engineering workflow call failed:    10s
    Wait Until Log Contains    ${LOG}    orchestration has not yet completed    10s
    Status Should Be    ${STATUS_1}    ${suspended_1}

    # 5. Resume, wait 2 seconds and read the status, in one block as on the page. The next leg
    # follows, and leg 1 isn't run again.
    ${out}=    Capture Command Output    ${RESUME_1}; sleep 2; ${STATUS_1}
    Block Should Show New Or Old Status    ${out}    202\n    ${running_1}    ${suspended_1}
    ${next}=    Evaluate    ${paused_at} + 1
    Wait Until Log Contains    ${LOG}    engineering jump-001 leg ${next}/10 complete    20s
    Count In File Should Be    ${LOG}    engineering jump-001 leg 1/10 complete    1

    # 6. Start jump-002, wait 7 seconds, terminate it, wait 2 seconds and read the status, in one
    # block as on the page. No legs follow.
    ${out}=    Capture Command Output    ${START_2}; sleep 7; ${TERMINATE_2}; sleep 2; ${STATUS_2}
    Block Should Show New Or Old Status    ${out}    ${started_2}\n202\n    ${terminated_2}    ${running_2}
    Wait Until Keyword Succeeds    20s    2s    Status Should Be    ${STATUS_2}    ${terminated_2}
    ${terminated_at}=    Settled Leg Count    jump-002
    Sleep    8s
    ${now}=    Leg Count    jump-002
    Should Be Equal As Integers    ${now}    ${terminated_at}    msg=A leg was logged after jump-002 was terminated
    # Pause on the finished jump: 409. Pause on an unknown jump: 404.
    ${out}=    Capture Command Output    ${PAUSE_2}
    Should Be Equal    ${out}    ${finished}\n409
    ${out}=    Capture Command Output    ${PAUSE_999}
    Should Be Equal    ${out}    ${not_found}\n404

    # 7. Purge jump-002 and read it, in one block as on the page: 204, then 404.
    ${out}=    Capture Command Output    ${PURGE_2}; ${GET_2}
    Should Be Equal    ${out}    204\n${not_found}\n404
    # jump-001 runs to the end after the resume.
    Wait Until Keyword Succeeds    90s    3s    Status Should Be    ${STATUS_1}    ${completed_1}
    Count In File Should Be    ${LOG}    engineering jump-001 leg 10/10 complete    1

    # 9. The same with the Dapr CLI, on jump-003.
    ${out}=    Capture Command Output    ${START_3}
    Should Be Equal    ${out}    ${started_3}
    Wait Until Log Contains    ${LOG}    engineering jump-003 leg 1/10 complete    10s
    ${list}=    Capture Command Output    dapr workflow list -a engineering
    # TypeScript's list has a CUSTOM STATUS column too: its SDK sets an empty custom status.
    Should Match Regexp    ${list}    (?m)^NAME\\s+ID\\s+STATUS\\s+(CUSTOM STATUS\\s+)?AGE
    Should Match Regexp    ${list}    (?m)^LongRangeJumpWorkflow\\s+jump-001\\s+COMPLETED\\s
    Should Match Regexp    ${list}    (?m)^LongRangeJumpWorkflow\\s+jump-003\\s+RUNNING\\s
    Should Not Contain    ${list}    jump-002
    ${out}=    Capture Command Output    dapr workflow suspend jump-003 -a engineering
    Should Contain    ${out}    Workflow 'jump-003' suspended successfully
    Wait Until Keyword Succeeds    20s    2s    Status Should Be    ${STATUS_3}    ${suspended_3}
    ${out}=    Capture Command Output    dapr workflow resume jump-003 -a engineering
    Should Contain    ${out}    Workflow 'jump-003' resumed successfully
    Wait Until Keyword Succeeds    20s    2s    Status Should Be    ${STATUS_3}    ${running_3}
    ${out}=    Capture Command Output    dapr workflow terminate jump-003 -a engineering
    Should Contain    ${out}    Workflow 'jump-003' terminated successfully
    Wait Until Keyword Succeeds    20s    2s    Status Should Be    ${STATUS_3}    ${terminated_3}
    ${out}=    Capture Command Output    dapr workflow purge jump-003 -a engineering
    Should Contain    ${out}    Purging 1 workflow instance(s)
    Should Contain    ${out}    Purged workflow instance "jump-003"
    ${out}=    Capture Command Output    curl -s -o /dev/null -w '\%{http_code}' http://localhost:5301/jumps/jump-003
    Should Be Equal    ${out}    404

    # 10. Clean up, while the app still runs. Only jump-001 is left, COMPLETED. Every page jump has
    # finished, so start jump-004 and pause it: the list shows it SUSPENDED, and the page's
    # terminate command (run for jump-004) ends it before the purge.
    ${list}=    Capture Command Output    dapr workflow list -a engineering
    Should Match Regexp    ${list}    (?m)^LongRangeJumpWorkflow\\s+jump-001\\s+COMPLETED\\s
    Should Not Contain    ${list}    jump-003
    ${out}=    Capture Command Output    ${START_4}
    Should Be Equal    ${out}    ${started_4}
    Wait Until Log Contains    ${LOG}    engineering jump-004 leg 1/10 complete    10s
    ${out}=    Capture Command Output    ${PAUSE_4}
    Should Be Equal    ${out}    202
    Wait Until Keyword Succeeds    20s    2s
    ...    Assert Command Output Contains    dapr workflow list -a engineering    SUSPENDED
    ${list}=    Capture Command Output    dapr workflow list -a engineering
    Should Match Regexp    ${list}    (?m)^LongRangeJumpWorkflow\\s+jump-004\\s+SUSPENDED\\s
    Run And Expect RC Zero    dapr workflow terminate jump-004 -a engineering
    Wait Until Keyword Succeeds    20s    2s
    ...    Assert Command Output Contains    curl -s http://localhost:5301/jumps/jump-004    "status":"TERMINATED"
    Run And Expect RC Zero    dapr workflow purge --all -a engineering
    ${list}=    Capture Command Output    dapr workflow list -a engineering
    Should Contain    ${list}    No workflow found
    FOR    ${id}    IN    jump-001    jump-004
        ${gone}=    Capture Command Output    curl -s -o /dev/null -w '\%{http_code}' http://localhost:5301/jumps/${id}
        Should Be Equal    ${gone}    404
    END

# doc-sync coverage (the commands are run above through keywords and variables that build them
# from the language and the folder, and with `\%` and `\\n` escaped for Robot; the commands of one
# page block run as one command, as on the page; the clean-up terminate command runs for jump-004):
#   cd /root/university-labs/workflow
#   cd dotnet/Demo6-Management
#   cd python/demo6-management
#   cd java/demo6-management
#   cd typescript/demo6-management
#   dapr run -f .
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq
#   sleep 8
#   curl -s -w ' %{http_code}\n' -X POST http://localhost:5301/jumps/jump-001/pause | jq
#   sleep 2
#   curl -s http://localhost:5301/jumps/jump-001 | jq
#   curl -s -w ' %{http_code}\n' -X DELETE http://localhost:5301/jumps/jump-001 | jq
#   curl -s -w ' %{http_code}\n' -X POST http://localhost:5301/jumps/jump-001/resume | jq
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002"}' | jq
#   sleep 7
#   curl -s -w ' %{http_code}\n' -X POST http://localhost:5301/jumps/jump-002/terminate | jq
#   curl -s http://localhost:5301/jumps/jump-002 | jq
#   curl -s -w ' %{http_code}\n' -X POST http://localhost:5301/jumps/jump-002/pause | jq
#   curl -s -w ' %{http_code}\n' -X POST http://localhost:5301/jumps/jump-999/pause | jq
#   curl -s -w ' %{http_code}\n' -X DELETE http://localhost:5301/jumps/jump-002 | jq
#   curl -s -w ' %{http_code}\n' http://localhost:5301/jumps/jump-002 | jq
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-003"}' | jq
#   dapr workflow list -a engineering
#   dapr workflow suspend jump-003 -a engineering
#   curl -s http://localhost:5301/jumps/jump-003 | jq
#   dapr workflow resume jump-003 -a engineering
#   dapr workflow terminate jump-003 -a engineering
#   dapr workflow purge jump-003 -a engineering
#   dapr workflow terminate jump-001 -a engineering
#   dapr workflow purge --all -a engineering
