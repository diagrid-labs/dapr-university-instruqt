*** Settings ***
Documentation     Drift test for dapr-101 challenge 4 (Service Invocation) across languages.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${BASE}       ${QUICKSTARTS_DIR}/service_invocation
${LOG}        ${TEMPDIR}/dapr-101-ch4.log

*** Test Cases ***
DotNet Service Invocation
    [Tags]    dotnet
    Run And Expect RC Zero    dotnet build csharp/http/checkout           ${BASE}
    Run And Expect RC Zero    dotnet build csharp/http/order-processor    ${BASE}
    Run Multi-App And Assert Markers
    ...    dapr run -f "csharp/http/dapr.yaml"    ${BASE}    ${LOG}    ${SVC_MARKERS}

Python Service Invocation
    [Tags]    python
    Run And Expect RC Zero    uv sync --all-packages    ${BASE}/python/http
    Run Multi-App And Assert Markers
    ...    uv run dapr run -f .    ${BASE}/python/http    ${LOG}    ${SVC_MARKERS}

Java Service Invocation
    [Tags]    java
    Run And Expect RC Zero    mvn clean install    ${BASE}/java/http/order-processor
    Run And Expect RC Zero    mvn clean install    ${BASE}/java/http/checkout
    Run Multi-App And Assert Markers
    ...    dapr run -f .    ${BASE}/java/http    ${LOG}    ${SVC_MARKERS}

JavaScript Service Invocation
    [Tags]    javascript
    Run And Expect RC Zero    npm install    ${BASE}/javascript/http/order-processor
    Run And Expect RC Zero    npm install    ${BASE}/javascript/http/checkout
    Run Multi-App And Assert Markers
    ...    dapr run -f .    ${BASE}/javascript/http    ${LOG}    ${SVC_MARKERS}

# doc-sync coverage (expressed via cwd arguments above):
#   cd python/http
#   cd java/http/order-processor
#   cd ../checkout
#   cd ..
#   cd javascript/http/order-processor
#   cd ../checkout
#   cd ..
