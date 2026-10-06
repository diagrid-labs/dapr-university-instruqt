*** Settings ***
Name              Ch1 Subscriptions
Documentation     Drift test for dapr-pubsub challenge 1: the declarative, programmatic and
...               streaming subscriptions in Demo1/Demo2/Demo3 of dapr-pub-sub-deep-dive.
...               Each test builds the demo's apps, starts them with `dapr run -f .`, publishes
...               with the assignment's curl command, and asserts on the receiver's log line.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-pubsub-ch1.log
${ID1}        11111111-1111-1111-1111-111111111111
${ID2}        22222222-2222-2222-2222-222222222222
${ID3}        33333333-3333-3333-3333-333333333333

*** Test Cases ***
Environment Is Ready
    [Documentation]    The assignment's two verification commands. Only the presence of a
    ...    version line is asserted here - dapr-101 challenge 2 owns the pinned-version check.
    [Tags]    dotnet
    Assert Command Output Contains    dapr -v    CLI version
    ${r}=    Run And Expect RC Zero    dotnet --version
    Should Match Regexp    ${r.stdout}    10[.]0[.]
    ...    msg=The demos target net10.0, but the SDK is not 10.0.x:\n${r.stdout}

Declarative Subscription
    [Documentation]    Demo1: a Subscription resource routes the topic to /messagehandler.
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    apps
    Run And Expect RC Zero    dotnet build SenderService      ${PUBSUB_DIR}/Demo1-Declarative
    Run And Expect RC Zero    dotnet build ReceiverService    ${PUBSUB_DIR}/Demo1-Declarative
    Start Workflow App    dapr run -f .    ${PUBSUB_DIR}/Demo1-Declarative    ${LOG}
    ...    http://localhost:5231/    apps
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5231/send --header 'content-type: application/json' --data '{"id":"${ID1}","timeStamp":"${TS}"}'
    Wait Until Log Contains    ${LOG}    Sent message ${ID1}.
    Wait Until Log Contains    ${LOG}    Received message ${ID1}.

Programmatic Subscription
    [Documentation]    Demo2: a [Topic] attribute reported via /dapr/subscribe.
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    apps
    Run And Expect RC Zero    dotnet build SenderService      ${PUBSUB_DIR}/Demo2-Programmatic
    Run And Expect RC Zero    dotnet build ReceiverService    ${PUBSUB_DIR}/Demo2-Programmatic
    Start Workflow App    dapr run -f .    ${PUBSUB_DIR}/Demo2-Programmatic    ${LOG}
    ...    http://localhost:5233/    apps
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"${ID2}","timeStamp":"${TS}"}'
    Wait Until Log Contains    ${LOG}    Received message ${ID2} via programmatic subscription.

Streaming Subscription
    [Documentation]    Demo3: a runtime subscription over a gRPC stream. The receiver exposes no
    ...    HTTP endpoint, so readiness is probed on the *sender* port. The subscription's
    ...    CancellationTokenSource cancels after 30s, hence the short publish window - if this
    ...    test starts failing on a timeout, check whether that timeout in the demo changed.
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    apps
    Run And Expect RC Zero    dotnet build SenderService      ${PUBSUB_DIR}/Demo3-Streaming
    Run And Expect RC Zero    dotnet build ReceiverService    ${PUBSUB_DIR}/Demo3-Streaming
    Start Workflow App    dapr run -f .    ${PUBSUB_DIR}/Demo3-Streaming    ${LOG}
    ...    http://localhost:5235/    apps
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5235/send --header 'content-type: application/json' --data '{"id":"${ID3}","timeStamp":"${TS}"}'
    Wait Until Log Contains    ${LOG}    Sent message ${ID3}.
    Wait Until Log Contains    ${LOG}    via streaming subscription.    30s

# doc-sync coverage (expressed via the cwd arguments above):
#   cd Demo1-Declarative
#   cd Demo2-Programmatic
#   cd Demo3-Streaming
#   cd ..
