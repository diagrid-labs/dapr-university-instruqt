*** Settings ***
Name              Ch2 CloudEvents
Documentation     Drift test for dapr-pubsub challenge 2 (CloudEvents). Asserts both the
...               default Dapr event type and the type overridden with publish metadata,
...               which are the two facts the assignment's expected output states.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${BASE}       ${PUBSUB_DIR}/Demo5-CloudEvents
${LOG}        ${TEMPDIR}/dapr-pubsub-ch2.log
${ID1}        44444444-4444-4444-4444-444444444444
${ID2}        55555555-5555-5555-5555-555555555555

*** Test Cases ***
CloudEvent Envelope Is Delivered To The Subscriber
    [Documentation]    The receiver binds CloudEvent<TinyMessage> instead of TinyMessage, so it
    ...    logs the envelope's type and source alongside the payload.
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    apps
    Run And Expect RC Zero    dotnet build SenderService      ${BASE}
    Run And Expect RC Zero    dotnet build ReceiverService    ${BASE}
    Start Workflow App    dapr run -f .    ${BASE}    ${LOG}    http://localhost:5233/    apps

    # 1. Default envelope: Dapr fills in type=com.dapr.event.sent and source=<app id>.
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"${ID1}","timeStamp":"${TS}"}'
    Wait Until Log Contains    ${LOG}    Received CloudEvent of type: com.dapr.event.sent from source: sender.
    Wait Until Log Contains    ${LOG}    Message received with ID: ${ID1}

    # 2. Overridden envelope: the sender passes cloudevent.type metadata on publish.
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5233/sendwithmetadata --header 'content-type: application/json' --data '{"id":"${ID2}","timeStamp":"${TS}"}'
    Wait Until Log Contains    ${LOG}    Received CloudEvent of type: special.type from source: sender.
    Wait Until Log Contains    ${LOG}    Message received with ID: ${ID2}

# doc-sync coverage (expressed via the cwd arguments above):
#   cd Demo5-CloudEvents
#   cd ..
