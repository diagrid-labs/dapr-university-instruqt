*** Settings ***
Name              Ch3 CloudEvents
Documentation     Drift test for dapr-pubsub page 3: demo 3 runs `order-api` and `shipping`. A normal
...               publish reaches shipping wrapped in a CloudEvent envelope (and shipping parses it
...               with the CloudEvents SDK), a publish with the `rawPayload` metadata arrives as the
...               bare order. The check scripts of the page then pass against the running demo.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - <appID> ==` and, in .NET and Java, a logger prefix too, so only the
...               message is matched. The order ID is unique per run because Redis can redeliver
...               older orders on startup.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-pubsub-ch3.log
${CH_DIR}           ${CURDIR}/..

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5101    5102    5103    3510    3511    3512
        Port Should Be Free    ${port}
    END

DotNet Shipping Receives Envelope And Raw Orders
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO3}[dotnet]/${ORDER_API}[dotnet]
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO3}[dotnet]/${SHIPPING}[dotnet]
    Walk Through CloudEvents    dotnet

Python Shipping Receives Envelope And Raw Orders
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO3}[python]/${ORDER_API}[python]
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO3}[python]/${SHIPPING}[python]
    Walk Through CloudEvents    python

Java Shipping Receives Envelope And Raw Orders
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO3}[java]/${ORDER_API}[java]
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO3}[java]/${SHIPPING}[java]
    Walk Through CloudEvents    java    timeout=300s

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

Walk Through CloudEvents
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${PUBSUB_BASE}/${lang}/${DEMO3}[${lang}]
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5101/    ${timeout}
    Wait Until App Responds    http://localhost:5102/    ${timeout}
    # Shipping's sidecar lists the orders-raw subscription once it has loaded the YAML files.
    Wait Until Command Output Contains    curl -s http://localhost:3511/v1.0/metadata    orders-raw    ${timeout}

    # 3. A normal publish: shipping logs the envelope and then the parsed attributes. The
    # assignment's order is o-3001, here the ID is unique per run.
    ${order}=    Evaluate    "o-" + str(int(time.time()))    modules=time
    ${response}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${order}","item":"coffee-beans","quantity":2,"priority":"standard"}'
    Should Be Equal    ${response}    {"orderId":"${order}","topic":"orders"}
    Wait Until Log Contains    ${LOG}    shipping received with envelope:    ${timeout}
    Wait Until Log Contains    ${LOG}    "orderId":"${order}"    ${timeout}
    Wait Until Log Contains    ${LOG}    shipping parsed CloudEvent id=    ${timeout}
    # The envelope carries the identifying attributes and the order in data. Field order varies
    # between SDKs, so each is matched on its own.
    FOR    ${field}    IN    "specversion":"1.0"    "source":"order-api"    "type":"com.dapr.event.sent"    "traceparent":    "id":    "data":{
        File Should Contain    ${LOG}    ${field}
    END
    File Should Contain    ${LOG}    type=com.dapr.event.sent source=order-api

    # 4. A raw publish: the bare order arrives, with no envelope.
    ${order2}=    Set Variable    ${order}-raw
    ${response}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders/raw -H 'Content-Type: application/json' -d '{"orderId":"${order2}","item":"coffee-beans","quantity":3,"priority":"express"}'
    Should Be Equal    ${response}    {"orderId":"${order2}","topic":"orders-raw"}
    Wait Until Log Contains    ${LOG}    shipping received raw: {"orderId":"${order2}","item":"coffee-beans","quantity":3,"priority":"express"}    ${timeout}

    # 6. The check scripts of the page pass against the running demo.
    FOR    ${name}    IN    apps-running    envelope    raw
        ${check}=    Run Process    bash    ${CH_DIR}/scripts/check-${name}.sh    stderr=STDOUT    timeout=60s
        ...    env:TRACKS_SRC_DIR=${TRACKS_SRC_DIR}
        Should Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh failed:\n${check.stdout}
    END

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder, or with a unique order ID instead of the assignment's o-3001 and o-3002):
#   cd /root/ai-agent-tracks-instruqt/pubsub
#   cd dotnet/Demo3-CloudEvents
#   cd python/demo3-cloud-events
#   cd java/demo3-cloud-events
#   dapr run -f .
#   curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
#     -d '{"orderId":"o-3001","item":"coffee-beans","quantity":2,"priority":"standard"}'
#   curl -s -X POST http://localhost:5101/orders/raw -H 'Content-Type: application/json' \
#     -d '{"orderId":"o-3002","item":"coffee-beans","quantity":3,"priority":"express"}'
