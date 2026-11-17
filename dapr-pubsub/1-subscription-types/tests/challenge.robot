*** Settings ***
Name              Ch1 Subscription Types
Documentation     Drift test for dapr-pubsub page 1: demo 1 runs three apps, `order-api`,
...               `shipping` (declarative subscription from YAML) and `invoicing` (programmatic
...               subscription from code). One order reaches both subscribers, and each sidecar's
...               metadata lists its subscription with the matching type.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - <appID> ==` and, in Java, a Spring prefix too, so only the message
...               is matched. The order ID is unique per run because Redis can redeliver older
...               orders on startup.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-pubsub-ch1.log
${CH_DIR}           ${CURDIR}/..
${ORDER_BODY}       "item":"coffee-beans","quantity":2,"priority":"standard"

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5101    5102    5103    3510    3511    3512
        Port Should Be Free    ${port}
    END

DotNet Both Subscribers Receive An Order
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO1}[dotnet]/${ORDER_API}[dotnet]
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO1}[dotnet]/${SHIPPING}[dotnet]
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO1}[dotnet]/${INVOICING}[dotnet]
    Walk Through Subscription Types    dotnet

Python Both Subscribers Receive An Order
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO1}[python]/${ORDER_API}[python]
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO1}[python]/${SHIPPING}[python]
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO1}[python]/${INVOICING}[python]
    Walk Through Subscription Types    python

Java Both Subscribers Receive An Order
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO1}[java]/${ORDER_API}[java]
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO1}[java]/${SHIPPING}[java]
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO1}[java]/${INVOICING}[java]
    Walk Through Subscription Types    java    timeout=300s

*** Keywords ***
Port Should Be Free
    [Arguments]    ${port}
    # curl exits 7 (connection refused) when nothing is listening. rc 0 means something answered.
    ${result}=    Run Process    curl -s -o /dev/null http://localhost:${port}/    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port ${port}. Stop the leaked app before running this suite.

Wait For The Ports To Be Free
    # The previous test's apps can take a moment to release the ports after SIGINT. Without this,
    # a readiness probe could be answered by the *previous* language's app.
    FOR    ${port}    IN    5101    5102    5103    3510    3511    3512
        Wait Until Keyword Succeeds    30s    1s    Port Should Be Free    ${port}
    END

Walk Through Subscription Types
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${PUBSUB_BASE}/${lang}/${DEMO1}[${lang}]
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5101/    ${timeout}
    Wait Until App Responds    http://localhost:5102/    ${timeout}
    Wait Until App Responds    http://localhost:5103/    ${timeout}
    # A sidecar answers the metadata call once it has loaded its subscriptions.
    Wait Until Command Output Contains    curl -s http://localhost:3512/v1.0/metadata    PROGRAMMATIC    ${timeout}

    # 4. One order to both. The assignment's order is o-1001, here the ID is unique per run.
    ${order}=    Evaluate    "o-" + str(int(time.time()))    modules=time
    ${response}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${order}",${ORDER_BODY}}'
    Should Be Equal    ${response}    {"orderId":"${order}","topic":"orders"}
    Wait Until Log Contains    ${LOG}    shipping received order ${order}    ${timeout}
    Wait Until Log Contains    ${LOG}    invoicing received order ${order}    ${timeout}

    # 5. The metadata endpoints name each subscription type, and the publisher has none.
    ${shipping}=    Capture Command Output    curl -s http://localhost:3511/v1.0/metadata | jq '.subscriptions'
    Should Contain    ${shipping}    "topic": "orders"
    Should Contain    ${shipping}    "type": "DECLARATIVE"
    Should Not Contain    ${shipping}    PROGRAMMATIC
    ${invoicing}=    Capture Command Output    curl -s http://localhost:3512/v1.0/metadata | jq '.subscriptions'
    Should Contain    ${invoicing}    "topic": "orders"
    Should Contain    ${invoicing}    "type": "PROGRAMMATIC"
    Should Not Contain    ${invoicing}    DECLARATIVE
    ${publisher}=    Capture Command Output    curl -s http://localhost:3510/v1.0/metadata | jq '.subscriptions'
    Should Be Equal    ${publisher}    null

    # 6. Shipping drops what is not a CloudEvent.
    ${dropped}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5102/orders -H 'Content-Type: application/json' -d 'not json'
    Should Contain    ${dropped}    DROP
    Wait Until Log Contains    ${LOG}    shipping dropped unreadable event    ${timeout}

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder, or with a unique order ID instead of the assignment's o-1001):
#   cd /root/ai-agent-tracks-instruqt/pubsub
#   cd dotnet/Demo1-Subscriptions
#   cd python/demo1-subscriptions
#   cd java/demo1-subscriptions
#   dapr run -f .
#   curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
#     -d '{"orderId":"o-1001","item":"coffee-beans","quantity":2,"priority":"standard"}' | jq
#   curl -s http://localhost:3511/v1.0/metadata | jq '.subscriptions'
#   curl -s http://localhost:3512/v1.0/metadata | jq '.subscriptions'
#   curl -s http://localhost:3510/v1.0/metadata | jq '.subscriptions'
#   curl -s -X POST http://localhost:5102/orders -H 'Content-Type: application/json' -d 'not json' | jq
