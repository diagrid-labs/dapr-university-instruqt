*** Settings ***
Name              Ch4 Routing
Documentation     Drift test for dapr-pubsub challenge 4 (content-based routing). Three
...               publishes to one topic must land in three different handlers: the
...               programmatic rules on receiver1 (including the priority tie-break) and
...               the declarative rule on receiver2.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${BASE}       ${PUBSUB_DIR}/Demo6-Routing
${LOG}        ${TEMPDIR}/dapr-pubsub-ch4.log
${ID1}        66666666-0000-0000-0000-000000000001
${ID2}        66666666-0000-0000-0000-000000000002
${ID3}        66666666-0000-0000-0000-000000000003

*** Test Cases ***
Messages Are Routed By Content
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    apps
    Run And Expect RC Zero    dotnet build SenderService       ${BASE}
    Run And Expect RC Zero    dotnet build ReceiverService1    ${BASE}
    Run And Expect RC Zero    dotnet build ReceiverService2    ${BASE}
    Start Workflow App    dapr run -f .    ${BASE}    ${LOG}    http://localhost:5233/    apps

    # type1 -> receiver1 /handletype1 (the lower-priority rule, since amount defaults to 0).
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"${ID1}","timeStamp":"${TS}","type":"dapr.demo.type1"}'
    Wait Until Log Contains    ${LOG}    Type1 - Received message ${ID1}: dapr.demo.type1.

    # type2 -> receiver2 /handletype2, via the declarative subscription's rules list.
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"${ID2}","timeStamp":"${TS}","type":"dapr.demo.type2"}'
    Wait Until Log Contains    ${LOG}    Type2 - Received message ${ID2}: dapr.demo.type2.

    # type1 with amount > 10 -> receiver1 /handlelargeamount. Both of receiver1's rules match,
    # so this asserts the priority tie-break (100 beats 200) still resolves the same way.
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"${ID3}","timeStamp":"${TS}","type":"dapr.demo.type1","amount":100}'
    Wait Until Log Contains    ${LOG}    Large amount - Received message ${ID3}: dapr.demo.type1.

# doc-sync coverage (expressed via the cwd arguments above):
#   cd Demo6-Routing
#   cd ..
