*** Settings ***
Name              Ch5 Pub Sub
Documentation     Drift test for dapr-101 page 5: `checkout-sdk` publishes orders to the `orders` topic and
...               `order-processor-sdk` receives them, started with `dapr run -f .` from the demo folder.
...               The subscription must show up in the sidecar metadata, and a message published through the
...               sidecar (what the Dev Dashboard Publish dialog does) must reach the subscriber.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-101-ch5.log
@{PORTS}      7006    6002    8080    5002    3500

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    [Tags]    dotnet    python    java    javascript
    FOR    ${port}    IN    @{PORTS}
        Port Should Be Free    ${port}
    END

DotNet Pub Sub
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Apps If Started
    ${dir}=    Set Variable    ${DAPR101_BASE}/dotnet/${PUBSUB_DEMO}[dotnet]
    # The page has no build step: the sandbox pre-builds and `dotnet run` builds. CI has no
    # pre-build, so build here to report a build error as such.
    Run And Expect RC Zero    dotnet build checkout    ${dir}
    Run And Expect RC Zero    dotnet build order-processor    ${dir}
    Run Apps And Check Subscription    dapr run -f .    ${dir}

Python Pub Sub
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Apps If Started
    ${dir}=    Set Variable    ${DAPR101_BASE}/python/${PUBSUB_DEMO}[python]
    # The page has no install step: the sandbox pre-installs and `uv run` syncs. CI has no
    # pre-install, so sync here to report an install error as such.
    Run And Expect RC Zero    uv sync --all-packages    ${dir}
    Run Apps And Check Subscription    uv run dapr run -f .    ${dir}

Java Pub Sub
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Apps If Started
    ${dir}=    Set Variable    ${DAPR101_BASE}/java/${PUBSUB_DEMO}[java]
    Run And Expect RC Zero    mvn -q -DskipTests install    ${dir}/order-processor
    Run And Expect RC Zero    mvn -q -DskipTests install    ${dir}/checkout
    Run Apps And Check Subscription    dapr run -f .    ${dir}    timeout=300s

JavaScript Pub Sub
    [Tags]    javascript
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Apps If Started
    ${dir}=    Set Variable    ${DAPR101_BASE}/javascript/${PUBSUB_DEMO}[javascript]
    Run And Expect RC Zero    npm install    ${dir}/order-processor
    Run And Expect RC Zero    npm install    ${dir}/checkout
    Run Apps And Check Subscription    dapr run -f .    ${dir}

*** Keywords ***
Port Should Be Free
    [Arguments]    ${port}
    # curl exits 7 (connection refused) when nothing is listening. rc 0 means something answered.
    ${result}=    Run Process    curl -s -o /dev/null http://localhost:${port}/    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port ${port}. Stop the leaked app before running this suite.

Wait For The Ports To Be Free
    # The previous test's apps can take a moment to release the ports after SIGINT.
    FOR    ${port}    IN    @{PORTS}
        Wait Until Keyword Succeeds    30s    1s    Port Should Be Free    ${port}
    END

Stop Apps If Started
    # A failed build never starts the `apps` process, so stopping a missing alias must not
    # mask the real failure.
    Run Keyword And Ignore Error    Stop Process With SIGINT    apps

Run Apps And Check Subscription
    [Documentation]    Start the apps under the alias `apps`, wait for the page's log markers, then check the
    ...    subscription and publish through the order-processor sidecar. The caller's teardown stops the apps.
    [Arguments]    ${run_command}    ${cwd}    ${timeout}=180s
    Start Background Process    ${run_command}    ${LOG}    apps    cwd=${cwd}
    FOR    ${marker}    IN    @{PUBSUB_MARKERS}
        Wait Until Log Contains    ${LOG}    ${marker}    ${timeout}
    END
    Wait Until Log Contains    ${LOG}    Started Dapr with app id "order-processor-sdk"    ${timeout}
    ${content}=    Get File    ${LOG}
    ${matches}=    Get Regexp Matches    ${content}
    ...    Started Dapr with app id "order-processor-sdk"\\. HTTP Port: (\\d+)    1
    ${port}=    Set Variable    ${matches}[0]
    Check Subscription And Publish    ${port}

Check Subscription And Publish
    [Arguments]    ${port}
    ${result}=    Wait Until Keyword Succeeds    60s    2s
    ...    Assert Command Output Contains    curl -s http://localhost:${port}/v1.0/metadata    "topic":"orders"
    Should Contain    ${result.stdout}    "pubsubname":"orderpubsub"
    Run And Expect RC Zero
    ...    curl -s -X POST -H "Content-Type: application/json" -d '{"orderId": 100}' http://localhost:${port}/v1.0/publish/orderpubsub/orders
    Wait Until Keyword Succeeds    60s    2s    Log Should Show Order 100 Received

Log Should Show Order 100 Received
    ${content}=    Get File    ${LOG}
    Should Match Regexp    ${content}    Subscriber received.*\\b100\\b

# doc-sync coverage (the commands run above through cwd= arguments and ${dir}):
#   cd /root/ai-agent-tracks-instruqt/dapr-101
#   cd dotnet/PubSub
#   cd python/pub-sub
#   cd java/pub-sub
#   cd javascript/pub-sub
#   cd order-processor
#   cd ../checkout
#   cd ..
#   mvn -q -DskipTests install
#   npm install
#   dapr run -f .
#   uv run dapr run -f .
