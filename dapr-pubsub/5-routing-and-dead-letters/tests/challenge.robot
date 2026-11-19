*** Settings ***
Name              Ch5 Routing And Dead Letters
Documentation     Drift test for dapr-pubsub page 5: demo 5 runs `order-api` and `shipping`. A
...               standard order is routed to /orders/standard, an express order to
...               /orders/express, and the poison order is rejected 4 times (the first try plus 3
...               retries) and then received by shipping from the dead-letter topic `orders-dead`.
...              
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - <appID> ==` and, in .NET and Java, a logger prefix too, so only the
...               message is matched. The order IDs are unique per run because Redis can redeliver
...               older orders on startup.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-pubsub-ch5.log
${CH_DIR}           ${CURDIR}/..

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5101    5102    5103    3510    3511    3512
        Port Should Be Free    ${port}
    END

DotNet Shipping Routes Orders And Dead-Letters The Poison Order
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO5}[dotnet]/${ORDER_API}[dotnet]
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO5}[dotnet]/${SHIPPING}[dotnet]
    Walk Through Routing    dotnet

Python Shipping Routes Orders And Dead-Letters The Poison Order
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO5}[python]/${ORDER_API}[python]
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO5}[python]/${SHIPPING}[python]
    Walk Through Routing    python

Java Shipping Routes Orders And Dead-Letters The Poison Order
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO5}[java]/${ORDER_API}[java]
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO5}[java]/${SHIPPING}[java]
    Walk Through Routing    java    timeout=300s

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

Walk Through Routing
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${PUBSUB_BASE}/${lang}/${DEMO5}[${lang}]
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5101/    ${timeout}
    Wait Until App Responds    http://localhost:5102/    ${timeout}
    # Shipping's sidecar lists the express route once it has loaded the subscription YAML.
    Wait Until Command Output Contains    curl -s http://localhost:3511/v1.0/metadata    /orders/express    ${timeout}

    # 4. Three orders: standard, express and poison. The assignment's IDs are o-5001 to o-5003,
    # here they carry a run prefix.
    ${run}=    Evaluate    "r" + str(int(time.time()))    modules=time
    ${r1}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${run}-5001","item":"coffee-beans","quantity":1,"priority":"standard"}'
    Should Contain    ${r1}    "orderId":"${run}-5001"
    Should Contain    ${r1}    "topic":"orders"
    ${r2}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${run}-5002","item":"coffee-beans","quantity":1,"priority":"express"}'
    Should Contain    ${r2}    "orderId":"${run}-5002"
    ${r3}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${run}-5003","item":"poison","quantity":1,"priority":"standard"}'
    Should Contain    ${r3}    "orderId":"${run}-5003"

    # 5. The routing, the retries and the dead-lettering, as the log of the assignment shows them.
    Wait Until Log Contains    ${LOG}    shipping standard order ${run}-5001    ${timeout}
    Wait Until Log Contains    ${LOG}    shipping express order ${run}-5002    ${timeout}
    Wait Until Log Contains    ${LOG}    shipping dead-lettered order ${run}-5003    ${timeout}
    ${text}=    Get File    ${LOG}
    # First try plus 3 retries.
    ${rejected}=    Evaluate    len(re.findall(r'shipping rejected order ${run}-5003', $text))    modules=re
    Should Be Equal As Integers    ${rejected}    4
    # The good orders are never dead-lettered or rejected.
    Should Not Contain    ${text}    shipping dead-lettered order ${run}-5001
    Should Not Contain    ${text}    shipping dead-lettered order ${run}-5002
    Should Not Contain    ${text}    shipping rejected order ${run}-5001
    Should Not Contain    ${text}    shipping rejected order ${run}-5002

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder, or with a unique order prefix instead of the assignment's o-500x IDs):
#   cd /root/university-labs/pubsub
#   cd dotnet/Demo5-RoutingDeadLetter
#   cd python/demo5-routing-dead-letter
#   cd java/demo5-routing-dead-letter
#   dapr run -f .
#   for o in \
#     '{"orderId":"o-5001","item":"coffee-beans","quantity":1,"priority":"standard"}' \
#     '{"orderId":"o-5002","item":"coffee-beans","quantity":1,"priority":"express"}' \
#     '{"orderId":"o-5003","item":"poison","quantity":1,"priority":"standard"}'; do
#     curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d "$o" | jq
#   done

