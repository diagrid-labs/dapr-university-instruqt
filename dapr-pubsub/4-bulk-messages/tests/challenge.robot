*** Settings ***
Name              Ch4 Bulk Messages
Documentation     Drift test for dapr-pubsub page 4: demo 4 runs `order-api` and `shipping`. One bulk
...               publish of 25 orders reaches shipping in batches (of at most 10 orders), and a
...               hand-made bulk body posted to shipping is answered SUCCESS for the complete
...               CloudEvent and DROP for the unreadable one. The check scripts of the page then
...               pass against the running demo.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - <appID> ==` and, in .NET and Java, a logger prefix too, so only the
...               message is matched. The batch sizes are not asserted exactly: they depend on
...               timing. The order prefix is unique per run because Redis can redeliver older
...               orders on startup.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-pubsub-ch4.log
${CH_DIR}           ${CURDIR}/..

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5101    5102    5103    3510    3511    3512
        Port Should Be Free    ${port}
    END

DotNet Shipping Receives Batches And Answers Per Entry
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO4}[dotnet]/${ORDER_API}[dotnet]
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO4}[dotnet]/${SHIPPING}[dotnet]
    Walk Through Bulk Messages    dotnet

Python Shipping Receives Batches And Answers Per Entry
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO4}[python]/${ORDER_API}[python]
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO4}[python]/${SHIPPING}[python]
    Walk Through Bulk Messages    python

Java Shipping Receives Batches And Answers Per Entry
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO4}[java]/${ORDER_API}[java]
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO4}[java]/${SHIPPING}[java]
    Walk Through Bulk Messages    java    timeout=300s

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

Walk Through Bulk Messages
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${PUBSUB_BASE}/${lang}/${DEMO4}[${lang}]
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5101/    ${timeout}
    Wait Until App Responds    http://localhost:5102/    ${timeout}
    # Shipping's sidecar lists the bulk route once it has loaded the subscription YAML.
    Wait Until Command Output Contains    curl -s http://localhost:3511/v1.0/metadata    /orders/bulk    ${timeout}

    # 3. One bulk publish of 25 orders. The assignment's prefix is bulk, here it is unique per run.
    ${run}=    Evaluate    "b" + str(int(time.time()))    modules=time
    ${response}=    Capture Command Output
    ...    curl -s -X POST 'http://localhost:5101/orders/bulk?count=25&prefix=${run}'
    ${sent}=    Evaluate    json.loads('''${response}''')    modules=json
    Should Be Equal As Integers    ${sent}[sent]    25
    Should Be Equal As Integers    ${sent}[failed]    0

    # 4. Shipping receives them in batches. Every order shows up in some batch line, and no batch
    # holds more than 10 orders.
    Wait Until Log Contains    ${LOG}    shipping received batch of    ${timeout}
    FOR    ${n}    IN RANGE    1    26
        Wait Until Log Contains    ${LOG}    ${run}-${n}    ${timeout}
    END
    ${text}=    Get File    ${LOG}
    ${sizes}=    Evaluate    [int(n) for n in re.findall(r'received batch of (\\d+) orders: [^\\n]*${run}-', $text)]    modules=re
    Should Not Be Empty    ${sizes}
    ${biggest}=    Evaluate    max($sizes)
    Should Be True    1 < ${biggest} <= 10    msg=batch sizes: ${sizes}

    # 5. The hand-made bulk body: e1 is a complete CloudEvent, e2 is not.
    ${answer}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5102/orders/bulk -H 'Content-Type: application/json' -d '{"entries":[{"entryId":"e1","event":{"data":{"orderId":"${run}-good","item":"coffee-beans","quantity":1,"priority":"standard"},"datacontenttype":"application/json","id":"e1-event","source":"curl","specversion":"1.0","type":"com.dapr.event.sent"},"contentType":"application/cloudevents+json"},{"entryId":"e2","event":{"nothing":"here"},"contentType":"application/cloudevents+json"}],"topic":"orders"}'
    ${statuses}=    Evaluate    {s["entryId"]: s["status"] for s in json.loads('''${answer}''')["statuses"]}    modules=json
    Should Be Equal    ${statuses}[e1]    SUCCESS
    Should Be Equal    ${statuses}[e2]    DROP
    Wait Until Log Contains    ${LOG}    shipping dropped unreadable entry e2    ${timeout}

    # 6. The check scripts of the page pass against the running demo.
    FOR    ${name}    IN    apps-running    batches    per-entry
        ${check}=    Run Process    bash    ${CH_DIR}/scripts/check-${name}.sh    stderr=STDOUT    timeout=60s
        ...    env:TRACKS_SRC_DIR=${TRACKS_SRC_DIR}
        Should Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh failed:\n${check.stdout}
    END

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder, or with a unique order prefix instead of the assignment's bulk and o-4001):
#   cd /root/ai-agent-tracks-instruqt/pubsub
#   cd dotnet/Demo4-Bulk
#   cd python/demo4-bulk
#   cd java/demo4-bulk
#   dapr run -f .
#   curl -s -X POST 'http://localhost:5101/orders/bulk?count=25&prefix=bulk'
#   curl -s -X POST http://localhost:5102/orders/bulk -H 'Content-Type: application/json' \
#     -d '{"entries":[{"entryId":"e1","event":{"data":{"orderId":"o-4001","item":"coffee-beans","quantity":1,"priority":"standard"},"datacontenttype":"application/json","id":"e1-event","source":"curl","specversion":"1.0","type":"com.dapr.event.sent"},"contentType":"application/cloudevents+json"},{"entryId":"e2","event":{"nothing":"here"},"contentType":"application/cloudevents+json"}],"topic":"orders"}'

# doc-sync coverage (the stop command of "Before you start" is for demos that Skip or Solve started
# in the background on the VM; the suite stops its own apps with Stop Process With SIGINT instead):
#   for f in /root/ai-agent-tracks-instruqt/pubsub/*/*/dapr.yaml; do (cd "$(dirname "$f")" && dapr stop -f . >/dev/null 2>&1); done; echo "No demo of this lab is running now."
