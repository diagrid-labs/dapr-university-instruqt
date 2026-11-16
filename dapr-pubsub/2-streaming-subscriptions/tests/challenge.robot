*** Settings ***
Name              Ch2 Streaming Subscriptions
Documentation     Drift test for dapr-pubsub page 2: demo 2 runs `order-api` and `warehouse`. The
...               warehouse has no app port and no Subscription file: it opens a stream to its own
...               sidecar, and the sidecar's metadata lists the subscription as STREAMING. An order
...               reaches it over the stream, and a text/plain message published through the
...               sidecar is logged as unreadable and acknowledged. The check scripts of the page
...               then pass against the running demo.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - <appID> ==` and, in .NET and Java, a logger prefix too, so only the
...               message is matched. The order ID is unique per run because Redis can redeliver
...               older orders on startup.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-pubsub-ch2.log
${CH_DIR}           ${CURDIR}/..

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5101    5102    5103    3510    3511    3512
        Port Should Be Free    ${port}
    END

DotNet Warehouse Receives Orders Over A Stream
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO2}[dotnet]/${ORDER_API}[dotnet]
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO2}[dotnet]/${WAREHOUSE}[dotnet]
    Walk Through Streaming Subscriptions    dotnet

Python Warehouse Receives Orders Over A Stream
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO2}[python]/${ORDER_API}[python]
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO2}[python]/${WAREHOUSE}[python]
    Walk Through Streaming Subscriptions    python

Java Warehouse Receives Orders Over A Stream
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO2}[java]/${ORDER_API}[java]
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO2}[java]/${WAREHOUSE}[java]
    Walk Through Streaming Subscriptions    java    timeout=300s

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

Walk Through Streaming Subscriptions
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${PUBSUB_BASE}/${lang}/${DEMO2}[${lang}]
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5101/    ${timeout}
    # The warehouse has no app port. Its metadata lists STREAMING once the stream is open, so
    # waiting for it means the order below cannot be published before the subscriber listens.
    Wait Until Command Output Contains    curl -s http://localhost:3511/v1.0/metadata    STREAMING    ${timeout}

    # 3. The sidecar of the warehouse names the subscription type.
    ${subs}=    Capture Command Output    curl -s http://localhost:3511/v1.0/metadata | jq '.subscriptions'
    Should Contain    ${subs}    "topic": "orders"
    Should Contain    ${subs}    "type": "STREAMING"
    Should Not Contain    ${subs}    DECLARATIVE

    # 4. One order over the stream. The assignment's order is o-2001, here the ID is unique per run.
    ${order}=    Evaluate    "o-" + str(int(time.time()))    modules=time
    ${response}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${order}","item":"coffee-beans","quantity":1,"priority":"standard"}'
    Should Be Equal    ${response}    {"orderId":"${order}","topic":"orders"}
    Wait Until Log Contains    ${LOG}    warehouse received order ${order}    ${timeout}

    # 5. A text/plain message through order-api's sidecar is accepted, logged as unreadable and
    # acknowledged, so the stream stays open for the next order.
    ${status}=    Capture Command Output
    ...    curl -s -w '\%{http_code}\\n' -X POST http://localhost:3510/v1.0/publish/pubsub/orders -H 'Content-Type: text/plain' -d 'not an order'
    Should Be Equal    ${status}    204
    Wait Until Log Contains    ${LOG}    warehouse dropped unreadable event    ${timeout}
    ${order2}=    Set Variable    ${order}-2
    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${order2}","item":"coffee-beans","quantity":1,"priority":"standard"}'
    Wait Until Log Contains    ${LOG}    warehouse received order ${order2}    ${timeout}

    # 6. The check scripts of the page pass against the running demo.
    FOR    ${name}    IN    apps-running    streaming    received
        ${check}=    Run Process    bash    ${CH_DIR}/scripts/check-${name}.sh    stderr=STDOUT    timeout=60s
        ...    env:TRACKS_SRC_DIR=${TRACKS_SRC_DIR}
        Should Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh failed:\n${check.stdout}
    END

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder, or with a unique order ID instead of the assignment's o-2001):
#   cd /root/ai-agent-tracks-instruqt/pubsub
#   cd dotnet/Demo2-Streaming
#   cd python/demo2-streaming
#   cd java/demo2-streaming
#   dapr run -f .
#   curl -s http://localhost:3511/v1.0/metadata | jq '.subscriptions'
#   curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
#     -d '{"orderId":"o-2001","item":"coffee-beans","quantity":1,"priority":"standard"}'
#   curl -s -w '%{http_code}\n' -X POST http://localhost:3510/v1.0/publish/pubsub/orders \
#     -H 'Content-Type: text/plain' -d 'not an order'

# doc-sync coverage (the stop command of "Before you start" is for demos that Skip or Solve started
# in the background on the VM; the suite stops its own apps with Stop Process With SIGINT instead):
#   for f in /root/ai-agent-tracks-instruqt/pubsub/*/*/dapr.yaml; do (cd "$(dirname "$f")" && dapr stop -f . >/dev/null 2>&1); done; echo "No demo of this track is running now."
