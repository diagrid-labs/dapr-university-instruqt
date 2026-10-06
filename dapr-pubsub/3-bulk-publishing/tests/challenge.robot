*** Settings ***
Name              Ch3 Bulk Publishing
Documentation     Drift test for dapr-pubsub challenge 3 (bulk publish + bulk subscribe).
...               One bulk publish of three messages must reach receiver1 three times
...               (ordinary subscription) and receiver2 in batches (bulk subscription).
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${BASE}       ${PUBSUB_DIR}/Demo4-Bulk
${LOG}        ${TEMPDIR}/dapr-pubsub-ch3.log
${ID1}        aaaaaaaa-0000-0000-0000-000000000001
${ID2}        aaaaaaaa-0000-0000-0000-000000000002
${ID3}        aaaaaaaa-0000-0000-0000-000000000003

*** Test Cases ***
Bulk Publish Reaches A Regular And A Bulk Subscriber
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    apps
    Run And Expect RC Zero    dotnet build SenderService       ${BASE}
    Run And Expect RC Zero    dotnet build ReceiverService1    ${BASE}
    Run And Expect RC Zero    dotnet build ReceiverService2    ${BASE}
    Start Workflow App    dapr run -f .    ${BASE}    ${LOG}    http://localhost:5237/    apps
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5237/send --header 'content-type: application/json' --data '[{"id":"${ID1}","timeStamp":"2026-01-01T12:00:00Z"},{"id":"${ID2}","timeStamp":"2026-01-01T12:00:01Z"},{"id":"${ID3}","timeStamp":"2026-01-01T12:00:02Z"}]'

    # The sender reports success only when BulkPublishResponse.FailedEntries is empty.
    Wait Until Log Contains    ${LOG}    Published multiple events!

    # receiver1 has an ordinary declarative subscription: one invocation per message.
    Wait Until Log Contains    ${LOG}    Received message ${ID1}.
    Wait Until Log Contains    ${LOG}    Received message ${ID2}.
    Wait Until Log Contains    ${LOG}    Received message ${ID3}.

    # receiver2 uses [BulkSubscribe] with a 500ms window, so the three messages can arrive
    # as one batch of 3 or split across smaller batches. Assert the batched *shape* of the
    # log line rather than an exact count, which is what the assignment's note warns about.
    Wait Until Log Matches    ${LOG}    Received [123] messages[.]

*** Keywords ***
Wait Until Log Matches
    [Documentation]    Like Wait Until Log Contains, but matches a regular expression against
    ...    the whole log. Robot strips backslashes from test data, so patterns use character
    ...    classes ([123], [.]) instead of escapes.
    [Arguments]    ${logfile}    ${pattern}    ${timeout}=60s
    Wait Until Keyword Succeeds    ${timeout}    2s    Log Should Match Regexp    ${logfile}    ${pattern}

Log Should Match Regexp
    [Arguments]    ${logfile}    ${pattern}
    ${content}=    Get File    ${logfile}
    Should Match Regexp    ${content}    ${pattern}
    ...    msg=No line matching "${pattern}" in ${logfile}

# doc-sync coverage (expressed via the cwd arguments above):
#   cd Demo4-Bulk
#   cd ..
