*** Settings ***
Name              Ch1 What Is The Secrets API
Documentation     Drift test for dapr-secrets challenge 1: each language's Demo1-ReadSecret app
...               reads a secret through the Dapr Secrets API from the local file store, and
...               reports a failed read in the same shape in every language.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_secrets.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}           ${TEMPDIR}/dapr-secrets-ch1.log
${APP_URL}       http://localhost:5001
# The values secrets.example.json (the single owner of the demo values) holds, as the
# assignment shows them. Every language returns compact JSON with "name" first.
${ORDERDB_JSON}     {"name":"orderdb-password","value":"s3cr3t-pa55w0rd"}
${PAYMENTS_JSON}    {"name":"payments-api-key","value":"pk-test-7f3a9"}
# The raw Dapr Secrets API response: the secret name maps to its value.
${RAW_JSON}         {"orderdb-password":"s3cr3t-pa55w0rd"}
# What every app returns for a name the store does not have: the HTTP status follows the Dapr
# failure (INTERNAL -> 500 here; PERMISSION_DENIED -> 403, which challenge 3 asserts) and the
# body carries the gRPC status name. curl appends the status after the body.
${UNKNOWN_JSON}     {"name":"does-not-exist","error":"INTERNAL"} 500

*** Test Cases ***
Port 5001 Is Free Before The App Starts
    [Documentation]    A process leaked by a previous run squats port 5001 and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    Port 5001 Should Be Free

DotNet Reads A Secret
    [Tags]    dotnet
    [Setup]    Wait For Port 5001 To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${SECRETS_BASE}/dotnet/${DEMO1}
    Read Secrets Through The App    ${SECRETS_BASE}/dotnet/${DEMO1}

DotNet Reports An Unknown Secret
    [Tags]    dotnet
    [Setup]    Wait For Port 5001 To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Start App And Wait Until It Serves Secrets    ${SECRETS_BASE}/dotnet/${DEMO1}
    Assert Unknown Secret Is Reported

Python Reads A Secret
    [Tags]    python
    [Setup]    Wait For Port 5001 To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${SECRETS_BASE}/python/${DEMO1}
    Read Secrets Through The App    ${SECRETS_BASE}/python/${DEMO1}

Python Reports An Unknown Secret
    [Tags]    python
    [Setup]    Wait For Port 5001 To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Start App And Wait Until It Serves Secrets    ${SECRETS_BASE}/python/${DEMO1}
    Assert Unknown Secret Is Reported

Java Reads A Secret
    [Tags]    java
    [Setup]    Wait For Port 5001 To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${SECRETS_BASE}/java/${DEMO1}
    Read Secrets Through The App    ${SECRETS_BASE}/java/${DEMO1}    timeout=300s

Java Reports An Unknown Secret
    [Tags]    java
    [Setup]    Wait For Port 5001 To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Start App And Wait Until It Serves Secrets    ${SECRETS_BASE}/java/${DEMO1}    timeout=300s
    Assert Unknown Secret Is Reported

*** Keywords ***
Port 5001 Should Be Free
    # curl exits 7 (connection refused) when nothing is listening. rc 0 means something answered.
    ${result}=    Run Process    curl -s -o /dev/null ${APP_URL}/    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port 5001. Stop the leaked app before running this suite.

Wait For Port 5001 To Be Free
    # The previous test's app can take a moment to release the port after SIGINT. Without this,
    # a readiness probe and identical JSON could be answered by the *previous* language's app.
    Wait Until Keyword Succeeds    30s    1s    Port 5001 Should Be Free

Start App And Wait Until It Serves Secrets
    [Arguments]    ${cwd}    ${timeout}=180s
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${cwd}
    Wait Until App Responds    ${APP_URL}/    ${timeout}
    # The app answers before its sidecar is ready, so poll for the first secret instead of
    # asserting once. The commands in this suite are spelled out literally (no variables)
    # because the doc-sync checker matches them against the assignment text.
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5001/secret/orderdb-password    ${ORDERDB_JSON}    ${timeout}

Read Secrets Through The App
    [Arguments]    ${cwd}    ${timeout}=180s
    Start App And Wait Until It Serves Secrets    ${cwd}    ${timeout}
    Assert Command Output Contains
    ...    curl -s http://localhost:5001/secret/payments-api-key    ${PAYMENTS_JSON}
    # The same value, straight from the Dapr Secrets API of the sidecar.
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/secrets/secretstore/orderdb-password    ${RAW_JSON}

Assert Unknown Secret Is Reported
    # `\%` keeps Robot from reading curl's %{http_code} as an environment variable.
    Assert Command Output Contains
    ...    curl -s -w ' \%{http_code}' http://localhost:5001/secret/does-not-exist    ${UNKNOWN_JSON}

# doc-sync coverage (expressed via cwd above):
#   cd dotnet/Demo1-ReadSecret
#   cd python/Demo1-ReadSecret
#   cd java/Demo1-ReadSecret
