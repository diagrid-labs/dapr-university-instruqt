*** Settings ***
Name              Ch5 Dead Lettering
Documentation     Drift test for dapr-pubsub challenge 5 (dead lettering). First asserts the
...               happy path, then applies the assignment's code change (429 instead of 202)
...               and asserts the rejected message reaches the DeadLetterService via the
...               subscription's deadLetterTopic. The receiver file is restored afterwards.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${BASE}        ${PUBSUB_DIR}/Demo7-Resiliency
${RECEIVER}    ${BASE}/ReceiverService/Program.cs
${BACKUP}      ${TEMPDIR}/dapr-pubsub-ch5-receiver-program.cs.bak
${LOG}         ${TEMPDIR}/dapr-pubsub-ch5.log
${ID1}         77777777-0000-0000-0000-000000000001
${ID2}         77777777-0000-0000-0000-000000000002

*** Test Cases ***
Accepted Message Is Not Dead Lettered
    [Documentation]    With the handler returning 202 Accepted, the deadletter app must stay
    ...    silent - if it doesn't, the demo's default response has drifted.
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    apps
    Build Demo7 Apps
    Start Workflow App    dapr run -f .    ${BASE}    ${LOG}    http://localhost:5233/    apps
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"${ID1}","timeStamp":"${TS}"}'
    Wait Until Log Contains    ${LOG}    Received message ${ID1}.
    ${content}=    Get File    ${LOG}
    Should Not Contain    ${content}    Received deadletter message ${ID1}.

Rejected Message Goes To The Dead Letter Topic
    [Documentation]    A 429 falls outside the resiliency policy's httpStatusCodes: 500-599
    ...    retry range, so Dapr must republish the message to deadletter-messages instead of
    ...    retrying it.
    [Tags]    dotnet
    [Teardown]    Run Keywords    Stop Process With SIGINT    apps
    ...    AND    Restore Receiver Program
    Reject Messages With 429
    Build Demo7 Apps
    Start Workflow App    dapr run -f .    ${BASE}    ${LOG}    http://localhost:5233/    apps
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"${ID2}","timeStamp":"${TS}"}'
    Wait Until Log Contains    ${LOG}    Received message ${ID2}.
    Wait Until Log Contains    ${LOG}    Received deadletter message ${ID2}.

*** Keywords ***
Build Demo7 Apps
    Run And Expect RC Zero    dotnet build SenderService       ${BASE}
    Run And Expect RC Zero    dotnet build ReceiverService     ${BASE}
    Run And Expect RC Zero    dotnet build DeadLetterService   ${BASE}

Reject Messages With 429
    [Documentation]    The same edit the assignment asks the learner to make in the Editor tab
    ...    (and that scripts/solve.sh applies): comment out the 202 response and activate the
    ...    429 one. The sed expressions avoid backslashes and runs of two or more spaces,
    ...    because Robot strips the former and splits arguments on the latter - hence the
    ...    [ ]* character class and the unindented replacement text.
    Copy File    ${RECEIVER}    ${BACKUP}
    Run And Expect RC Zero
    ...    sed -i 's|^[ ]*return Results.Accepted();|//return Results.Accepted();|' ${RECEIVER}
    Run And Expect RC Zero
    ...    sed -i 's|^[ ]*//return Results.Problem("Too many requests"|return Results.Problem("Too many requests"|' ${RECEIVER}
    # Both replacements drop the original indentation, so the edited lines start at column 0.
    ${content}=    Get File    ${RECEIVER}
    Should Match Regexp    ${content}    (?m)^//return Results[.]Accepted[(][)];
    ...    msg=The 202 response line was not commented out - has Demo7's ReceiverService changed?
    Should Match Regexp    ${content}    (?m)^return Results[.]Problem[(]"Too many requests"
    ...    msg=The 429 response line was not activated - has Demo7's ReceiverService changed?

Restore Receiver Program
    Move File    ${BACKUP}    ${RECEIVER}

# doc-sync coverage (expressed via the cwd arguments above):
#   cd Demo7-Resiliency
#   cd ..
