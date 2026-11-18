*** Settings ***
Name              Ch4 Service Invocation
Documentation     Drift test for dapr-101 page 4: `checkout` calls `order-processor` through the
...               Dapr service invocation API, started with `dapr run -f .` from the demo folder.
...               The logs must show an order received by `order-processor` and passed by `checkout`.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-101-ch4.log

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    7001    8001    9001    5001    3500
        Port Should Be Free    ${port}
    END

DotNet Service Invocation
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Apps If Started
    ${dir}=    Set Variable    ${DAPR101_BASE}/dotnet/${SVC_DEMO}[dotnet]
    Run And Expect RC Zero    dotnet build checkout    ${dir}
    Run And Expect RC Zero    dotnet build order-processor    ${dir}
    Run Apps And Assert Markers    dapr run -f .    ${dir}    ${LOG}    ${SVC_MARKERS}

Python Service Invocation
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Apps If Started
    ${dir}=    Set Variable    ${DAPR101_BASE}/python/${SVC_DEMO}[python]
    Run And Expect RC Zero    uv sync --all-packages    ${dir}
    Run Apps And Assert Markers    uv run dapr run -f .    ${dir}    ${LOG}    ${SVC_MARKERS}

Java Service Invocation
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Apps If Started
    ${dir}=    Set Variable    ${DAPR101_BASE}/java/${SVC_DEMO}[java]
    Run And Expect RC Zero    mvn -q -DskipTests install    ${dir}/order-processor
    Run And Expect RC Zero    mvn -q -DskipTests install    ${dir}/checkout
    Run Apps And Assert Markers    dapr run -f .    ${dir}    ${LOG}    ${SVC_MARKERS}    timeout=300s

JavaScript Service Invocation
    [Tags]    javascript
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Apps If Started
    ${dir}=    Set Variable    ${DAPR101_BASE}/javascript/${SVC_DEMO}[javascript]
    Run And Expect RC Zero    npm install    ${dir}/order-processor
    Run And Expect RC Zero    npm install    ${dir}/checkout
    Run Apps And Assert Markers    dapr run -f .    ${dir}    ${LOG}    ${SVC_MARKERS}

*** Keywords ***
Port Should Be Free
    [Arguments]    ${port}
    # curl exits 7 (connection refused) when nothing is listening. rc 0 means something answered.
    ${result}=    Run Process    curl -s -o /dev/null http://localhost:${port}/    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port ${port}. Stop the leaked app before running this suite.

Wait For The Ports To Be Free
    # The previous test's apps can take a moment to release the ports after SIGINT.
    FOR    ${port}    IN    7001    8001    9001    5001    3500
        Wait Until Keyword Succeeds    30s    1s    Port Should Be Free    ${port}
    END

Stop Apps If Started
    # A failed build never starts the `apps` process, so stopping a missing alias must not
    # mask the real failure.
    Run Keyword And Ignore Error    Stop Process With SIGINT    apps

Run Apps And Assert Markers
    [Documentation]    Start the apps under the alias `apps` and wait for each log marker. The caller's
    ...    teardown stops the apps, also when a marker never shows up.
    [Arguments]    ${run_command}    ${cwd}    ${logfile}    ${markers}    ${timeout}=180s
    Start Background Process    ${run_command}    ${logfile}    apps    cwd=${cwd}
    FOR    ${marker}    IN    @{markers}
        Wait Until Log Contains    ${logfile}    ${marker}    ${timeout}
    END

# doc-sync coverage (the commands run above through cwd= arguments and ${dir}):
#   cd /root/ai-agent-tracks-instruqt/dapr-101
#   cd dotnet/ServiceInvocation
#   cd python/service-invocation
#   cd java/service-invocation
#   cd javascript/service-invocation
#   cd order-processor
#   cd ../checkout
#   cd ..
#   dotnet build checkout
#   dotnet build order-processor
#   uv sync --all-packages
#   mvn -q -DskipTests install
#   npm install
#   dapr run -f .
#   uv run dapr run -f .
