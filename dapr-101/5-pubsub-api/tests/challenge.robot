# This suite mirrors challenge 4's structure (see 4-service-invocation-api for the
# fuller syntax walkthrough): one tagged test per language, each building the apps
# and then running them together while waiting for expected log markers.

*** Settings ***
Documentation     Drift test for dapr-101 challenge 5 (Pub/Sub) across languages.
Resource          ../../../tools/track-tester/resources/dapr.resource
# Imports ${QUICKSTARTS_DIR} and the ${PUBSUB_MARKERS} list from the Python vars file.
Variables         ../../../tools/track-tester/variables/dapr_101.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${BASE}       ${QUICKSTARTS_DIR}/pub_sub
${LOG}        ${TEMPDIR}/dapr-101-ch5.log

*** Test Cases ***
DotNet Pub Sub
    # `[Tags]` lets you run one language in isolation, e.g. `robot --include dotnet`.
    [Tags]    dotnet
    Run And Expect RC Zero    dotnet build csharp/sdk/checkout           ${BASE}
    Run And Expect RC Zero    dotnet build csharp/sdk/order-processor    ${BASE}
    Run Multi-App And Assert Markers
    ...    dapr run -f "csharp/sdk/dapr.yaml"    ${BASE}    ${LOG}    ${PUBSUB_MARKERS}

Python Pub Sub
    [Tags]    python
    Run And Expect RC Zero    uv sync --all-packages    ${BASE}/python/sdk
    Run Multi-App And Assert Markers
    ...    uv run dapr run -f .    ${BASE}/python/sdk    ${LOG}    ${PUBSUB_MARKERS}

Java Pub Sub
    [Tags]    java
    Run And Expect RC Zero    mvn clean install    ${BASE}/java/sdk/order-processor
    Run And Expect RC Zero    mvn clean install    ${BASE}/java/sdk/checkout
    Run Multi-App And Assert Markers
    ...    dapr run -f .    ${BASE}/java/sdk    ${LOG}    ${PUBSUB_MARKERS}

JavaScript Pub Sub
    [Tags]    javascript
    Run And Expect RC Zero    npm install    ${BASE}/javascript/sdk/order-processor
    Run And Expect RC Zero    npm install    ${BASE}/javascript/sdk/checkout
    Run Multi-App And Assert Markers
    ...    dapr run -f .    ${BASE}/javascript/sdk    ${LOG}    ${PUBSUB_MARKERS}

# doc-sync coverage (expressed via cwd arguments above):
#   cd python/sdk
#   cd java/sdk/order-processor
#   cd ../checkout
#   cd ..
#   cd javascript/sdk/order-processor
#   cd ../checkout
#   cd ..
