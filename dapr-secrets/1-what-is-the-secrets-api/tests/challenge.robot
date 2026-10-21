*** Settings ***
Name              Ch1 What Is The Secrets API
Documentation     Drift test for dapr-secrets challenge 1: each language's Demo1-ReadSecret app
...               reads a secret through the Dapr Secrets API from the local file store.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_secrets.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}           ${TEMPDIR}/dapr-secrets-ch1.log
${APP_URL}       http://localhost:5001
# The values secrets.example.json (the single owner of the demo values) holds, as the
# assignment shows them. Every language returns compact JSON with "name" before "value".
${ORDERDB_JSON}     {"name":"orderdb-password","value":"s3cr3t-pa55w0rd"}
${PAYMENTS_JSON}    {"name":"payments-api-key","value":"pk-test-7f3a9"}
# The raw Dapr Secrets API response: the secret name maps to its value.
${RAW_JSON}         {"orderdb-password":"s3cr3t-pa55w0rd"}

*** Test Cases ***
Port 5001 Is Free Before The App Starts
    [Documentation]    A process leaked by a previous run squats port 5001 and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    # curl exits 7 (connection refused) when nothing is listening. rc 0 means something answered.
    ${result}=    Run Process    curl -s -o /dev/null ${APP_URL}/    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port 5001. Stop the leaked app before running this suite.

DotNet Reads A Secret
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${SECRETS_BASE}/dotnet/${DEMO1}
    Read Secrets Through The App    ${SECRETS_BASE}/dotnet/${DEMO1}

Python Reads A Secret
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${SECRETS_BASE}/python/${DEMO1}
    Read Secrets Through The App    ${SECRETS_BASE}/python/${DEMO1}

Java Reads A Secret
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${SECRETS_BASE}/java/${DEMO1}
    Read Secrets Through The App    ${SECRETS_BASE}/java/${DEMO1}    timeout=300s

*** Keywords ***
Read Secrets Through The App
    [Arguments]    ${cwd}    ${timeout}=180s
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${cwd}
    Wait Until App Responds    ${APP_URL}/    ${timeout}
    # The app answers before its sidecar is ready, so poll for the first secret instead of
    # asserting once. The commands below are spelled out literally (no variables) because
    # the doc-sync checker matches them against the assignment text.
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5001/secret/orderdb-password    ${ORDERDB_JSON}    ${timeout}
    Assert Command Output Contains
    ...    curl -s http://localhost:5001/secret/payments-api-key    ${PAYMENTS_JSON}
    # The same value, straight from the Dapr Secrets API of the sidecar.
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/secrets/secretstore/orderdb-password    ${RAW_JSON}

# doc-sync coverage (expressed via cwd above):
#   cd dotnet/Demo1-ReadSecret
#   cd python/Demo1-ReadSecret
#   cd java/Demo1-ReadSecret
