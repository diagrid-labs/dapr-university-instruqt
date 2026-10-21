*** Settings ***
Name              Ch2 The Component And Its Parameters
Documentation     Drift test for dapr-secrets challenge 2: the bulk endpoint of each language's
...               Demo1-ReadSecret app, the raw bulk API, the nestedSeparator and multiValued
...               parameters of the local file secret store, and a state store component whose
...               password comes from the secret store through secretKeyRef.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_secrets.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-secrets-ch2.log
${CONTROL_DIR}      ${TEMPDIR}/dapr-secrets-ch2-control
${APP_URL}          http://localhost:5001
# The values secrets.example.json (the single owner of the demo values) holds, as the
# assignment shows them.
${ORDERDB_JSON}     {"name":"orderdb-password","value":"s3cr3t-pa55w0rd"}
# The app's bulk endpoint: one flat object, keys sorted, identical in every language.
${BULK_JSON}        {"orderdb-password":"s3cr3t-pa55w0rd","payments-api-key":"pk-test-7f3a9"}
# The raw Dapr bulk API wraps every secret in a map of its own (Go sorts the keys).
${RAW_BULK_JSON}    {"orderdb-password":{"orderdb-password":"s3cr3t-pa55w0rd"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
# The nested-demo folder: one nested secrets file read by three components that differ only
# in nestedSeparator / multiValued.
${NESTED_DIR}       ${SECRETS_BASE}/nested-demo
${NESTED_DEFAULT}   {"orderdb:password":{"orderdb:password":"s3cr3t-pa55w0rd"},"orderdb:user":{"orderdb:user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
${NESTED_FLAT}      {"orderdb.password":{"orderdb.password":"s3cr3t-pa55w0rd"},"orderdb.user":{"orderdb.user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
${NESTED_MULTI}     {"orderdb":{"password":"s3cr3t-pa55w0rd","user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
${MULTI_ORDERDB}    {"password":"s3cr3t-pa55w0rd","user":"orders"}
# What daprd logs when a secretKeyRef points at a secret the store does not have, and when the
# state store component was loaded. The first is the failure a learner would hit; the second
# proves the component came up.
${MISSING_REF_KEY}  not-in-the-store
${REF_FAILURE}      Error getting secret: secret ${MISSING_REF_KEY} not found
${STATESTORE_LOADED}    Component loaded: statestore (state.redis/v1)

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats port 5001 or 3500 and makes the
    ...    next `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    Port 5001 Should Be Free
    Port 3500 Should Be Free

DotNet Reads All Secrets
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${SECRETS_BASE}/dotnet/${DEMO1}
    Read All Secrets Through The App    ${SECRETS_BASE}/dotnet/${DEMO1}

Python Reads All Secrets
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${SECRETS_BASE}/python/${DEMO1}
    Read All Secrets Through The App    ${SECRETS_BASE}/python/${DEMO1}

Java Reads All Secrets
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${SECRETS_BASE}/java/${DEMO1}
    Read All Secrets Through The App    ${SECRETS_BASE}/java/${DEMO1}    timeout=300s

Nested Secrets Follow NestedSeparator And MultiValued
    [Tags]    component
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    nested
    Start Background Process
    ...    dapr run --app-id nested-demo --dapr-http-port 3500 --resources-path resources
    ...    ${LOG}    nested    cwd=${NESTED_DIR}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/secrets/nested-default/bulk    ${NESTED_DEFAULT}    60s
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/secrets/nested-flat/bulk    ${NESTED_FLAT}
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/secrets/nested-multi/bulk    ${NESTED_MULTI}
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/secrets/nested-multi/orderdb    ${MULTI_ORDERDB}

An Unresolvable SecretKeyRef Is Reported By The Sidecar
    [Documentation]    Negative control for the secretKeyRef proof in the language tests. A copy of
    ...    the real component that points at a secret the store does not have must make daprd log
    ...    the failure. If it does not, the "no error logged" assertion in the language tests would
    ...    stay green through a broken indirection and prove nothing.
    [Tags]    component
    [Setup]    Prepare The Control Folder
    [Teardown]    Stop Process With SIGINT    control
    Start Background Process
    ...    dapr run --app-id secretref-control --dapr-http-port 3500 --resources-path resources
    ...    ${LOG}    control    cwd=${CONTROL_DIR}
    Wait Until Log Contains    ${LOG}    ${REF_FAILURE}    60s

*** Keywords ***
Port 5001 Should Be Free
    # curl exits 7 (connection refused) when nothing is listening. rc 0 means something answered.
    ${result}=    Run Process    curl -s -o /dev/null ${APP_URL}/    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port 5001. Stop the leaked app before running this suite.

Port 3500 Should Be Free
    ${result}=    Run Process    curl -s -o /dev/null http://localhost:3500/v1.0/healthz    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port 3500. Stop the leaked sidecar before running this suite.

Wait For The Ports To Be Free
    # The previous test's processes can take a moment to release the ports after SIGINT. Without
    # this, a readiness probe and identical JSON could be answered by the *previous* test's app.
    Wait Until Keyword Succeeds    30s    1s    Port 5001 Should Be Free
    Wait Until Keyword Succeeds    30s    1s    Port 3500 Should Be Free

Read All Secrets Through The App
    [Arguments]    ${cwd}    ${timeout}=180s
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${cwd}
    Wait Until App Responds    ${APP_URL}/    ${timeout}
    # The app answers before its sidecar is ready, so poll for the first secret instead of
    # asserting once. The commands in this suite are spelled out literally (no variables)
    # because the doc-sync checker matches them against the assignment text.
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5001/secret/orderdb-password    ${ORDERDB_JSON}    ${timeout}
    Assert Command Output Contains    curl -s http://localhost:5001/secrets    ${BULK_JSON}
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/secrets/secretstore/bulk    ${RAW_BULK_JSON}
    Assert SecretKeyRef Resolves    ${cwd}

Assert SecretKeyRef Resolves
    [Arguments]    ${cwd}
    # 1. The state store works through the sidecar: it was initialised with a password that came
    #    out of the secret store. (Dapr's Redis container accepts the password but does not
    #    require it, so this alone cannot tell a resolved password from an empty one.)
    Run And Expect RC Zero
    ...    curl -s -X POST -H "Content-Type: application/json" -d '[{"key":"order-1","value":"queued"}]' http://localhost:3500/v1.0/state/statestore
    Assert Command Output Contains    curl -s http://localhost:3500/v1.0/state/statestore/order-1    "queued"
    # 2. The sidecar's own log (multi-app run writes it to .dapr/logs, newest file first) says the
    #    component was loaded and contains no failed secret lookup. The negative-control test
    #    proves that a broken reference does produce the failure line asserted absent here.
    ${log}=    Capture Command Output
    ...    cat "$(ls -t .dapr/logs/order-api_daprd_*.log | head -1)"    ${cwd}
    Should Contain    ${log}    ${STATESTORE_LOADED}
    Should Not Contain    ${log}    Error getting secret

Prepare The Control Folder
    # A throwaway sidecar folder built from the real committed components: the same
    # statestore-with-secretref.yaml with its secretKeyRef changed to a secret that is not in the
    # store, next to the real secret store component pointing at a copy of the real secrets.
    Remove Directory    ${CONTROL_DIR}    recursive=True
    Create Directory    ${CONTROL_DIR}/resources
    Copy File    ${SECRETS_BASE}/secrets.example.json    ${CONTROL_DIR}/secrets.json
    ${store}=    Get File    ${SECRETS_BASE}/python/resources/secretstore-local.yaml
    ${store}=    Replace String    ${store}    ../../secrets.json    ./secrets.json
    Create File    ${CONTROL_DIR}/resources/secretstore-local.yaml    ${store}
    ${state}=    Get File    ${SECRETS_BASE}/python/resources/statestore-with-secretref.yaml
    Should Contain    ${state}    orderdb-password
    ${state}=    Replace String    ${state}    orderdb-password    ${MISSING_REF_KEY}
    Create File    ${CONTROL_DIR}/resources/statestore-with-secretref.yaml    ${state}
    Wait For The Ports To Be Free

# doc-sync coverage (expressed via cwd and cwd-relative paths above):
#   cd dotnet/Demo1-ReadSecret
#   cd python/Demo1-ReadSecret
#   cd java/Demo1-ReadSecret
#   cd ../../nested-demo
#   dapr run -f .                  (Read All Secrets Through The App, cwd = demo folder)
#   dapr run --app-id nested-demo --dapr-http-port 3500 --resources-path resources
#                                  (Nested Secrets Follow NestedSeparator And MultiValued)
