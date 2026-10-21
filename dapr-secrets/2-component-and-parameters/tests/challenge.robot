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
${CONTROL_ROOT}     ${TEMPDIR}/dapr-secrets-ch2-control
${APP_URL}          http://localhost:5001
# The values secrets.example.json (the single owner of the demo values) holds, as the
# assignment shows them.
${ORDERDB_JSON}     {"name":"orderdb-password","value":"s3cr3t-pa55w0rd"}
# The app's bulk endpoint: one flat object, keys sorted, identical in every language.
${BULK_JSON}        {"orderdb-password":"s3cr3t-pa55w0rd","payments-api-key":"pk-test-7f3a9"}
# The raw Dapr bulk API wraps every secret in a map of its own (Go sorts the keys).
${RAW_BULK_JSON}    {"orderdb-password":{"orderdb-password":"s3cr3t-pa55w0rd"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
# The nested-demo folder: one nested secrets file read by three components that differ only
# in nestedSeparator / multiValued. Its values are demo data, deliberately not the real demo
# values, so secrets.example.json stays the single owner of those.
${NESTED_DIR}       ${SECRETS_BASE}/nested-demo
${NESTED_DEFAULT}   {"orderdb:password":{"orderdb:password":"demo-nested-password"},"orderdb:user":{"orderdb:user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
${NESTED_FLAT}      {"orderdb.password":{"orderdb.password":"demo-nested-password"},"orderdb.user":{"orderdb.user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
${NESTED_MULTI}     {"orderdb":{"password":"demo-nested-password","user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
${MULTI_ORDERDB}    {"password":"demo-nested-password","user":"orders"}

# The sidecar log wording below is what daprd 1.18.x writes (confirmed on 1.18.7). It is
# undocumented, so a runtime bump that rewords it should fail here as drift, not as a mystery:
# update these strings and the matching sentences in assignment.md together.
${STATESTORE_LOADED}    Component loaded: statestore (state.redis/v1)
${SECRET_NOT_FOUND}     Error getting secret: secret not-in-the-store not found
${STORE_NOT_LOADED}     references a secret store that isn't loaded
${MISSING_NAME}         not-in-the-store

# A throwaway sidecar's dapr.yaml. YAML is a superset of JSON, so this one-line flow form
# avoids indentation inside a Robot cell. The appID matches the real demos so that the control
# sidecars write the same .dapr/logs/order-api_daprd_*.log file the assertions read.
${CONTROL_APPS}     {"version": 1, "common": {"resourcesPath": "./resources"}, "apps": [{"appID": "order-api", "appDirPath": "./", "daprHTTPPort": 3500, "command": ["sleep", "300"]}]}
# Value-level proof fixtures (test-only, never shipped): a secrets file holding a state key
# prefix, and a Redis state store whose keyPrefix comes from it through secretKeyRef.
${PREFIX_SECRETS}   {"state-prefix": "prefix-from-store"}
${PROOF_KEYS}       "prefix-from-store||ref-proof" "order-api||ref-proof" "||ref-proof"

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

# Negative controls for the secretKeyRef assertion in the language tests. Each one starts a
# multi-app run (`dapr run -f .`, the same way as the demos) from a throwaway folder holding a
# copy of the REAL statestore-with-secretref.yaml with one thing broken, and reads the SAME sink
# the assertion reads (the newest .dapr/logs/order-api_daprd_*.log, through Read Newest Sidecar
# Log). A guard is only a guard once the path it reads has been seen to fire.

A Wrong SecretKeyRef Name Is Logged By The Sidecar
    [Tags]    component    control
    Control Variant Starts    wrong-name    name: orderdb-password    name: ${MISSING_NAME}
    Wait For Sidecar Log To Contain    wrong-name    ${SECRET_NOT_FOUND}
    # The command the assignment's break-it exercise gives the learner, literally.
    Assert Command Output Contains
    ...    grep -h "Error getting secret" .dapr/logs/order-api_daprd_*.log    ${SECRET_NOT_FOUND}    ${CONTROL_ROOT}/wrong-name
    ${log}=    Read Newest Sidecar Log    ${CONTROL_ROOT}/wrong-name
    Should Contain    ${log}    ${STATESTORE_LOADED}
    [Teardown]    Stop Process With SIGINT    control

A Wrong SecretStore In Auth Is Logged And The Component Does Not Load
    [Tags]    component    control
    Control Variant Starts    wrong-store    secretStore: secretstore    secretStore: nostore
    Wait For Sidecar Log To Contain    wrong-store    ${STORE_NOT_LOADED}: nostore
    ${log}=    Read Newest Sidecar Log    ${CONTROL_ROOT}/wrong-store
    Should Not Contain    ${log}    ${STATESTORE_LOADED}
    [Teardown]    Stop Process With SIGINT    control

A Missing Auth Block Is Logged
    [Tags]    component    control
    # Drop everything from `auth:` on, leaving a secretKeyRef with no store to resolve against.
    Control Variant Starts    no-auth    ${EMPTY}    ${EMPTY}    drop_auth=${TRUE}
    Wait For Sidecar Log To Contain    no-auth    ${STORE_NOT_LOADED}:
    [Teardown]    Stop Process With SIGINT    control

A Wrong SecretKeyRef Key Is Silent With The Local File Store
    [Documentation]    Documents a blind spot instead of guarding against it: with this store a wrong
    ...    `key` (right `name`) logs no error at all, so the log assertions cannot catch it. If a
    ...    runtime starts logging it, this test fails and the log assertions should learn the new line.
    [Tags]    component    control
    Control Variant Starts    wrong-key    key: orderdb-password    key: ${MISSING_NAME}
    Wait For Sidecar Log To Contain    wrong-key    ${STATESTORE_LOADED}
    ${log}=    Read Newest Sidecar Log    ${CONTROL_ROOT}/wrong-key
    Should Not Contain    ${log}    Error getting secret
    Should Not Contain    ${log}    ${STORE_NOT_LOADED}
    [Teardown]    Stop Process With SIGINT    control

A Secret Store Value Reaches The Component
    [Documentation]    The value-level proof. keyPrefix is taken from the secret store through
    ...    secretKeyRef, and it is observable: Redis stores the key under that prefix. A reference
    ...    that did not substitute would store it under another prefix, so seeing this exact key
    ...    shows a value crossed from the secret store into the component. (redisHost cannot serve
    ...    here: an empty redisHost silently falls back to localhost:6379 and still works.)
    [Tags]    component    value
    [Setup]    Delete Proof Keys
    Value Proof Starts    value-proof    state-prefix
    Save A Proof Value Through The Sidecar
    ${keys}=    Capture Command Output    docker exec dapr_redis redis-cli KEYS '*ref-proof*'
    Should Contain    ${keys}    prefix-from-store||ref-proof
    [Teardown]    Finish Value Proof

A Missing Secret Leaves The Component Value Empty
    [Documentation]    Negative control for the value-level proof: with the reference pointing at a
    ...    secret that is not there, the same observation must come out differently.
    [Tags]    component    value
    [Setup]    Delete Proof Keys
    Value Proof Starts    value-proof-missing    ${MISSING_NAME}
    Save A Proof Value Through The Sidecar
    ${keys}=    Capture Command Output    docker exec dapr_redis redis-cli KEYS '*ref-proof*'
    Should Contain    ${keys}    ||ref-proof
    Should Not Contain    ${keys}    prefix-from-store||ref-proof
    [Teardown]    Finish Value Proof

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
    # The state store works through the sidecar. (Dapr's Redis container does not require a
    # password, so this alone cannot tell a resolved password from an empty one.)
    Run And Expect RC Zero
    ...    curl -s -X POST -H "Content-Type: application/json" -d '[{"key":"order-1","value":"queued"}]' http://localhost:3500/v1.0/state/statestore
    Assert Command Output Contains    curl -s http://localhost:3500/v1.0/state/statestore/order-1    "queued"
    # The sidecar's own log says the component loaded and holds none of the failure lines. The
    # control tests above show that each of those lines really appears in this same log when the
    # reference is broken, and the value-level test shows a value does cross over.
    ${log}=    Read Newest Sidecar Log    ${cwd}
    Should Contain    ${log}    ${STATESTORE_LOADED}
    Should Not Contain    ${log}    Error getting secret
    Should Not Contain    ${log}    ${STORE_NOT_LOADED}
    # The command the assignment gives the learner, literally, over every sidecar log in the folder.
    Assert Command Output Contains
    ...    grep -h "Component loaded: statestore" .dapr/logs/order-api_daprd_*.log    ${STATESTORE_LOADED}    ${cwd}

Read Newest Sidecar Log
    # The one place that reads the sidecar log, for the assertion and for every control. A
    # multi-app run writes it to .dapr/logs under the folder it ran from, newest file last run.
    [Arguments]    ${cwd}
    ${log}=    Capture Command Output
    ...    cat "$(ls -t .dapr/logs/order-api_daprd_*.log | head -1)"    ${cwd}
    RETURN    ${log}

Sidecar Log Should Contain
    [Arguments]    ${cwd}    ${text}
    ${log}=    Read Newest Sidecar Log    ${cwd}
    Should Contain    ${log}    ${text}

Wait For Sidecar Log To Contain
    [Arguments]    ${name}    ${text}
    Wait Until Keyword Succeeds    60s    2s
    ...    Sidecar Log Should Contain    ${CONTROL_ROOT}/${name}    ${text}

Prepare Sidecar Folder
    # A throwaway folder for `dapr run -f .`: the real secret store component (secretsFile
    # pointed at the folder's own secrets.json), the given secrets and state store component,
    # and a dapr.yaml with a do-nothing app.
    [Arguments]    ${name}    ${secrets}    ${statestore}
    ${dir}=    Set Variable    ${CONTROL_ROOT}/${name}
    Remove Directory    ${dir}    recursive=True
    Create Directory    ${dir}/resources
    Create File    ${dir}/secrets.json    ${secrets}
    ${store}=    Get File    ${SECRETS_BASE}/python/resources/secretstore-local.yaml
    ${store}=    Replace String    ${store}    ../../secrets.json    ./secrets.json
    Create File    ${dir}/resources/secretstore-local.yaml    ${store}
    Create File    ${dir}/resources/statestore-with-secretref.yaml    ${statestore}
    Create File    ${dir}/dapr.yaml    ${CONTROL_APPS}
    Wait For The Ports To Be Free
    Start Background Process    dapr run -f .    ${LOG}    control    cwd=${dir}

Control Variant Starts
    # Start a sidecar whose state store is a copy of the real statestore-with-secretref.yaml
    # with `old` replaced by `new` (or everything from `auth:` on dropped).
    [Arguments]    ${name}    ${old}    ${new}    ${drop_auth}=${FALSE}
    ${state}=    Get File    ${SECRETS_BASE}/python/resources/statestore-with-secretref.yaml
    IF    ${drop_auth}
        ${state}=    Evaluate    $state[:$state.index("auth:")]
    ELSE
        Should Contain    ${state}    ${old}
        ${state}=    Replace String    ${state}    ${old}    ${new}
    END
    ${secrets}=    Get File    ${SECRETS_BASE}/secrets.example.json
    Prepare Sidecar Folder    ${name}    ${secrets}    ${state}

Value Proof Starts
    [Arguments]    ${name}    ${secret_name}
    ${state}=    Catenate    {"apiVersion": "dapr.io/v1alpha1", "kind": "Component",
    ...    "metadata": {"name": "statestore"}, "spec": {"type": "state.redis", "version": "v1",
    ...    "metadata": [{"name": "redisHost", "value": "localhost:6379"},
    ...    {"name": "keyPrefix", "secretKeyRef": {"name": "${secret_name}", "key": "${secret_name}"}}]},
    ...    "auth": {"secretStore": "secretstore"}}
    Prepare Sidecar Folder    ${name}    ${PREFIX_SECRETS}    ${state}

Save A Proof Value Through The Sidecar
    Wait Until Keyword Succeeds    60s    2s    Run And Expect RC Zero
    ...    curl -s -f -X POST -H "Content-Type: application/json" -d '[{"key":"ref-proof","value":"from-store"}]' http://localhost:3500/v1.0/state/statestore

Delete Proof Keys
    Run Process    docker exec dapr_redis redis-cli DEL ${PROOF_KEYS}    shell=True

Finish Value Proof
    Stop Process With SIGINT    control
    Delete Proof Keys

# doc-sync coverage (expressed via cwd and cwd-relative paths above):
#   cd dotnet/Demo1-ReadSecret
#   cd python/Demo1-ReadSecret
#   cd java/Demo1-ReadSecret
#   cd ../../nested-demo
#   dapr run -f .                  (Read All Secrets Through The App, cwd = demo folder)
#   dapr run --app-id nested-demo --dapr-http-port 3500 --resources-path resources
#                                  (Nested Secrets Follow NestedSeparator And MultiValued)
#   cd dotnet/Demo1-ReadSecret, cd python/Demo1-ReadSecret, cd java/Demo1-ReadSecret
#                                  (the same folders, entered in the curl window for the log greps)
