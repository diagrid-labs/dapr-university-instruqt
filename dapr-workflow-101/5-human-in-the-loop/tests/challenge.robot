*** Settings ***
Name              Ch5 Human In The Loop
Documentation     Drift test for dapr-workflow-101 page 5: demo 5 runs `engineering`, whose
...               `AuthorizedJumpWorkflow` plots the course and then waits for the external event
...               `jump-authorized`, for at most 60 seconds. `POST /jumps/{jumpId}/authorize` raises
...               that event. The suite approves `jump-001`, denies `jump-002`, lets `jump-003` time
...               out, and then authorizes the finished `jump-003` and expects `409 JUMP_FINISHED`.
...
...               The page's clean-up terminates a jump that is still waiting before it purges. After
...               the page's steps every jump has finished, so the suite starts `jump-004` and leaves
...               it waiting, so the list and terminate commands have a running jump to act on.
...
...               The authorize calls print the HTTP status after the body, through the page's
...               `curl -s -w ' %{http_code}\n' <url> | jq`: jq reads the body and then the status as a
...               second JSON value. The 202 has no body, so only the status is printed.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - engineering ==` and, in .NET, Python and Java, a logger prefix too, so only
...               the message is matched. The TypeScript SDK logs extra lines of its own; none of them
...               contains the messages matched here.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-workflow-101-ch5.log
# The page's expected outputs, as compact JSON; jq prints them formatted.
${STARTED_1}        {"jumpId":"jump-001"}
${STARTED_2}        {"jumpId":"jump-002"}
${STARTED_3}        {"jumpId":"jump-003"}
${STARTED_4}        {"jumpId":"jump-004"}
${WAITING_1}        {"jumpId":"jump-001","status":"RUNNING","output":null}
${JUMPED_1}         {"jumpId":"jump-001","status":"COMPLETED","output":{"status":"JUMPED","authorizedBy":"Captain Ilsa Varn"}}
${DENIED_2}         {"jumpId":"jump-002","status":"COMPLETED","output":{"status":"DENIED","authorizedBy":"Captain Ilsa Varn"}}
${ABORTED_3}        {"jumpId":"jump-003","status":"COMPLETED","output":{"status":"ABORTED_NO_AUTHORIZATION"}}
${FINISHED}         {"error":"JUMP_FINISHED"}
${STATUS_3}         curl -s http://localhost:5301/jumps/jump-003 | jq
${APPROVE_1}        curl -s -w ' \%{http_code}\\n' -X POST http://localhost:5301/jumps/jump-001/authorize -H 'Content-Type: application/json' -d '{"approved": true, "officer": "Captain Ilsa Varn"}' | jq
${DENY_2}           curl -s -w ' \%{http_code}\\n' -X POST http://localhost:5301/jumps/jump-002/authorize -H 'Content-Type: application/json' -d '{"approved": false, "officer": "Captain Ilsa Varn"}' | jq
${APPROVE_3}        curl -s -w ' \%{http_code}\\n' -X POST http://localhost:5301/jumps/jump-003/authorize -H 'Content-Type: application/json' -d '{"approved": true, "officer": "Captain Ilsa Varn"}' | jq

*** Test Cases ***
Ports Are Free Before The App Starts
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5301    3530    50330
        Port Should Be Free    ${port}
    END

DotNet Approve Deny And Time Out
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    dotnet build    ${WF101_BASE}/${DEMO5}[dotnet]/Engineering
    Walk Through Human In The Loop    dotnet

Python Approve Deny And Time Out
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    uv sync    ${WF101_BASE}/${DEMO5}[python]/engineering
    Walk Through Human In The Loop    python

Java Approve Deny And Time Out
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Run And Expect RC Zero    mvn -q -DskipTests package    ${WF101_BASE}/${DEMO5}[java]/engineering
    Walk Through Human In The Loop    java    timeout=300s

TypeScript Approve Deny And Time Out
    [Tags]    typescript
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Clean Up And Stop
    Directory Should Exist    ${WF101_BASE}/${DEMO5}[typescript]/engineering/node_modules
    Walk Through Human In The Loop    typescript

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
    # waiting, then purge. The test body already ran it and checked it; this repeat only matters
    # when the test failed before that point, so its result is ignored.
    Run Process
    ...    for id in $(dapr workflow list -a engineering -s RUNNING -o ids); do dapr workflow terminate $id -a engineering; done
    ...    shell=True
    Run Process    dapr workflow purge --all -a engineering    shell=True
    Stop Process With SIGINT    app

Walk Through Human In The Loop
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${WF101_BASE}/${DEMO5}[${lang}]

    # 2. Run the demo.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    ${APP_URL}/    ${timeout}

    # 3. Start jump-001, wait 3 seconds and read the status, in one block as on the page. The
    # course takes about a second to plot, then the workflow waits for the captain.
    ${out}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq; sleep 3; curl -s http://localhost:5301/jumps/jump-001 | jq
    ${started}=    Pretty Json    ${STARTED_1}
    ${waiting}=    Pretty Json    ${WAITING_1}
    Should Be Equal    ${out}    ${started}\n${waiting}
    Wait Until Log Contains    ${LOG}    engineering jump-001 awaiting captain's authorization    10s

    # 4. Approve jump-001, wait 3 seconds and read the status, in one block as on the page.
    ${out}=    Capture Command Output    ${APPROVE_1}; sleep 3; curl -s http://localhost:5301/jumps/jump-001 | jq
    ${jumped}=    Pretty Json    ${JUMPED_1}
    Should Be Equal    ${out}    202\n${jumped}
    Wait Until Log Contains    ${LOG}    engineering jump complete, arrived at Vesper Reach    10s

    # 5. Start jump-002, deny it and read the status, in one block as on the page.
    ${out}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002"}' | jq; sleep 3; ${DENY_2}; sleep 2; curl -s http://localhost:5301/jumps/jump-002 | jq
    ${started}=    Pretty Json    ${STARTED_2}
    ${denied}=    Pretty Json    ${DENIED_2}
    Should Be Equal    ${out}    ${started}\n202\n${denied}
    Wait Until Log Contains    ${LOG}    engineering jump-002 jump denied by Captain Ilsa Varn    10s

    # 6. Start jump-003 and send nothing.
    ${out}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-003"}' | jq
    ${started}=    Pretty Json    ${STARTED_3}
    Should Be Equal    ${out}    ${started}
    Wait Until Log Contains    ${LOG}    engineering jump-003 awaiting captain's authorization    10s

    # 7. The status command as on the page, run until the 60-second wait has passed.
    ${aborted}=    Pretty Json    ${ABORTED_3}
    Wait Until Keyword Succeeds    90s    3s    Status Should Be    ${STATUS_3}    ${aborted}
    Wait Until Log Contains    ${LOG}    engineering jump-003 jump aborted, no authorization    10s

    # 8. Authorize the finished jump-003: 409, and the output stays as it was.
    ${out}=    Capture Command Output    ${APPROVE_3}
    ${finished}=    Pretty Json    ${FINISHED}
    Should Be Equal    ${out}    ${finished}\n409
    Status Should Be    ${STATUS_3}    ${aborted}

    # Each jump logs its awaiting line once: the replays don't log it again.
    Count In File Should Be    ${LOG}    engineering jump-001 awaiting captain's authorization    1
    Count In File Should Be    ${LOG}    engineering jump-003 awaiting captain's authorization    1
    Count In File Should Be    ${LOG}    engineering jump complete, arrived at    1

    # 9. Clean up, while the app still runs. Every page jump has finished, so start jump-004 and
    # leave it waiting: the list shows it, and the page's terminate command (run for jump-004)
    # ends it before the purge.
    ${out}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-004"}' | jq
    ${started}=    Pretty Json    ${STARTED_4}
    Should Be Equal    ${out}    ${started}
    Wait Until Log Contains    ${LOG}    engineering jump-004 awaiting captain's authorization    10s
    ${list}=    Capture Command Output    dapr workflow list -a engineering -s RUNNING
    Should Contain    ${list}    jump-004
    Should Not Contain    ${list}    jump-001
    Should Not Contain    ${list}    jump-003
    Run And Expect RC Zero    dapr workflow terminate jump-004 -a engineering
    Wait Until Keyword Succeeds    20s    2s
    ...    Assert Command Output Contains    curl -s http://localhost:5301/jumps/jump-004    "status":"TERMINATED"
    ${list}=    Capture Command Output    dapr workflow list -a engineering -s RUNNING
    Should Contain    ${list}    No workflow found
    Run And Expect RC Zero    dapr workflow purge --all -a engineering
    FOR    ${id}    IN    jump-001    jump-002    jump-003    jump-004
        ${gone}=    Capture Command Output    curl -s -o /dev/null -w '\%{http_code}' http://localhost:5301/jumps/${id}
        Should Be Equal    ${gone}    404
    END

Status Should Be
    [Arguments]    ${command}    ${expected}
    ${out}=    Capture Command Output    ${command}
    Should Be Equal    ${out}    ${expected}

Count In File Should Be
    [Arguments]    ${file}    ${text}    ${expected}
    ${content}=    Get File    ${file}
    ${count}=    Get Count    ${content}    ${text}
    Should Be Equal As Integers    ${count}    ${expected}

# doc-sync coverage (the commands are run above through keywords and variables that build them
# from the language and the folder, and with `\%` and `\\n` escaped for Robot; the commands of one
# page block run as one command, as on the page; the terminate command runs for jump-004):
#   cd /root/university-labs/workflow
#   cd dotnet/Demo5-HumanInTheLoop
#   cd python/demo5-human-in-the-loop
#   cd java/demo5-human-in-the-loop
#   cd typescript/demo5-human-in-the-loop
#   dapr run -f .
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq
#   sleep 3
#   curl -s http://localhost:5301/jumps/jump-001 | jq
#   curl -s -w ' %{http_code}\n' -X POST http://localhost:5301/jumps/jump-001/authorize -H 'Content-Type: application/json' -d '{"approved": true, "officer": "Captain Ilsa Varn"}' | jq
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002"}' | jq
#   curl -s -w ' %{http_code}\n' -X POST http://localhost:5301/jumps/jump-002/authorize -H 'Content-Type: application/json' -d '{"approved": false, "officer": "Captain Ilsa Varn"}' | jq
#   sleep 2
#   curl -s http://localhost:5301/jumps/jump-002 | jq
#   curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-003"}' | jq
#   curl -s http://localhost:5301/jumps/jump-003 | jq
#   curl -s -w ' %{http_code}\n' -X POST http://localhost:5301/jumps/jump-003/authorize -H 'Content-Type: application/json' -d '{"approved": true, "officer": "Captain Ilsa Varn"}' | jq
#   dapr workflow list -a engineering -s RUNNING
#   dapr workflow terminate jump-003 -a engineering
#   dapr workflow purge --all -a engineering
