*** Settings ***
Name              Ch4 Swap The Provider
Documentation     Drift test for dapr-secrets challenge 4, the end of the track: the secret store
...               moves from a local file to HashiCorp Vault and the application is not touched.
...               Per language it runs the unmodified Demo1-ReadSecret app twice, once against the
...               local file store and once through Demo3-SwapProvider, which points the very same
...               app at a resources folder whose `secretstore` component is Vault.
...
...               Ruling 3: the "no code change" claim is scoped to the SWAP. The source tree of
...               Demo1-ReadSecret as it stands when this challenge begins is fingerprinted before
...               the local-file run, between the two runs and after the Vault run, and all three
...               fingerprints must be equal. It is deliberately NOT compared with challenge 1's
...               version of the app: challenge 2 added the bulk endpoint, so that comparison
...               would be false by construction.
...
...               The shared resources folder cannot simply gain a second component: Dapr refuses
...               to start when two components in one folder have the same name (see the
...               "Two Components With One Name" test), which is why the Vault component lives in
...               Demo3-SwapProvider/resources next to a copy of the state store component.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_secrets.py
Suite Teardown    Run Keywords    Terminate All Processes    kill=True
...               AND    Delete Vault Test Secrets

*** Variables ***
${LOG}                ${TEMPDIR}/dapr-secrets-ch4.log
${LOG_SOLVE}          ${TEMPDIR}/dapr-secrets-ch4-solve.log
${CONTROL_ROOT}       ${TEMPDIR}/dapr-secrets-ch4-control
${CH_DIR}             ${CURDIR}/..
${SANDBOX_SETUP}      ${CURDIR}/../../_setup/sandbox-setup.sh
${APP_URL}            http://localhost:5001
# The values secrets.example.json (the single owner of the demo values) holds.
${ORDERDB_JSON}       {"name":"orderdb-password","value":"s3cr3t-pa55w0rd"}
${PAYMENTS_JSON}      {"name":"payments-api-key","value":"pk-test-7f3a9"}
# The app's bulk endpoint: one flat object, keys sorted, identical in every language. No closing
# brace: Vault returns every secret it holds, so the Vault-only secret the test adds follows.
${BULK_JSON}          {"orderdb-password":"s3cr3t-pa55w0rd","payments-api-key":"pk-test-7f3a9"
# A secret that exists in Vault and nowhere else (it is not in secrets.json). The assignment
# creates it by hand; the suite creates it the same way.
${VAULT_ONLY_JSON}    {"name":"shipping-token","value":"from-vault"}
${VAULT_ONLY_MISSING}    {"name":"shipping-token","error":"${APP_MISSING_ERROR}"}
${APP_MISSING}        {"name":"legacy-api-key","error":"${APP_MISSING_ERROR}"}
${APP_DENIED}         {"name":"orderdb-password","error":"${APP_DENIED_ERROR}"}
# `dapr` lists the loaded components, with their type, on its metadata endpoint.
${LOCAL_TYPE}         "name":"secretstore","type":"secretstores.local.file"
${VAULT_TYPE}         "name":"secretstore","type":"secretstores.hashicorp.vault"
${STATESTORE_TYPE}    "name":"statestore","type":"state.redis"
# Daprd 1.18.x log wording, pinned as in challenges 2 and 3 so a runtime change fails the suite.
${STATESTORE_LOADED}    Component loaded: statestore (state.redis/v1)
${SECRET_ERROR_LOG}     Error getting secret
${STORE_NOT_LOADED}     references a secret store that isn't loaded
${MISSING_NAME}         not-in-the-store
${VAULT_URL}            http://localhost:8200
# Vault answers 200 on /v1/sys/health when it is initialized, unsealed and active.
${VAULT_CLI}            docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=root vault vault
${PROOF_KEYS}           "prefix-from-vault||ref-proof" "vault-proof||ref-proof" "||ref-proof"
# What fingerprints the app: every file of the source tree except build and run output.
${FINGERPRINT}          find ${DEMO1} -type f -not -path '*/bin/*' -not -path '*/obj/*' -not -path '*/target/*' -not -path '*/.venv/*' -not -path '*/.dapr/*' -not -path '*/__pycache__/*' | LC_ALL=C sort | xargs sha256sum

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats port 5001 or 3500 and makes the
    ...    next `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    Port 5001 Should Be Free
    Port 3500 Should Be Free

Vault Answers Its Health Endpoint Before Any App Starts
    [Documentation]    Review focus 3: the sandbox starts Vault, and the apps only ever see it
    ...    through the sidecar. Prove here, before a single app runs, that it is up and holds the
    ...    seeded secrets, so a Vault problem is never mistaken for a sidecar problem.
    [Tags]    vault
    Assert Command Output Contains
    ...    curl -s -o /dev/null -w '\%{http_code}' ${VAULT_URL}/v1/sys/health    200
    ${orderdb}=    Capture Command Output
    ...    curl -s -H "X-Vault-Token: root" ${VAULT_URL}/v1/secret/data/dapr/orderdb-password
    Should Contain    ${orderdb}    s3cr3t-pa55w0rd
    ${payments}=    Capture Command Output
    ...    curl -s -H "X-Vault-Token: root" ${VAULT_URL}/v1/secret/data/dapr/payments-api-key
    Should Contain    ${payments}    pk-test-7f3a9
    # legacy-api-key is deliberately not in secrets.json, so challenge 3's allowed-but-absent
    # secret is absent here too.
    ${legacy}=    Run Process
    ...    curl -s -o /dev/null -w '\%{http_code}' -H "X-Vault-Token: root" ${VAULT_URL}/v1/secret/data/dapr/legacy-api-key
    ...    shell=True
    Should Be Equal    ${legacy.stdout}    404

The Vault Wait Loop Fails When Vault Never Becomes Ready
    [Documentation]    Review focus 3: the readiness wait in sandbox-setup.sh must return non-zero
    ...    with a clear message when Vault never answers, instead of leaving the learner with an
    ...    opaque sidecar error. The real loop is cut out of the real script and run with a
    ...    `docker` that always fails (and a `sleep` that does not sleep); a second run with a
    ...    `docker` that succeeds proves the loop also lets a ready Vault through.
    [Tags]    vault
    ${script}=    Get File    ${SANDBOX_SETUP}
    ${start}=    Evaluate    $script.index("vault_ready=false")
    ${end}=    Evaluate    $script.index("exit 1", $start) + len("exit 1")
    ${loop}=    Evaluate    $script[$start:$end] + chr(10) + "fi" + chr(10)
    Should Contain    ${loop}    seq 1 30
    ${shim_dir}=    Set Variable    ${TEMPDIR}/dapr-secrets-ch4-shim
    Remove Directory    ${shim_dir}    recursive=True
    Create Directory    ${shim_dir}
    Create File    ${shim_dir}/sleep    \#!/bin/bash\nexit 0\n
    Create File    ${shim_dir}/docker    \#!/bin/bash\nexit 1\n
    Run Process    chmod    +x    ${shim_dir}/sleep    ${shim_dir}/docker
    Create File    ${shim_dir}/loop.sh    set -euo pipefail\n${loop}
    ${down}=    Run Process    bash    ${shim_dir}/loop.sh    stderr=STDOUT
    ...    env:PATH=${shim_dir}:%{PATH}    timeout=60s
    Should Not Be Equal As Integers    ${down.rc}    0
    Should Contain    ${down.stdout}    Vault did not become ready within 30 seconds
    Create File    ${shim_dir}/docker    \#!/bin/bash\nexit 0\n
    ${up}=    Run Process    bash    ${shim_dir}/loop.sh    stderr=STDOUT
    ...    env:PATH=${shim_dir}:%{PATH}    timeout=60s
    Should Be Equal As Integers    ${up.rc}    0    msg=${up.stdout}

Two Components With One Name Do Not Load
    [Documentation]    The reason the Vault component sits in its own folder. Putting
    ...    secretstore-vault.yaml next to secretstore-local.yaml would make `dapr run` fail for
    ...    challenges 1 to 3 too. If a runtime starts accepting that, the folder split is no longer
    ...    needed and this test says so.
    [Tags]    component
    [Setup]    Wait For The Ports To Be Free
    ${dir}=    Set Variable    ${CONTROL_ROOT}/duplicate
    Remove Directory    ${dir}    recursive=True
    Create Directory    ${dir}/resources
    Copy File    ${SECRETS_BASE}/python/resources/secretstore-local.yaml    ${dir}/resources/secretstore-local.yaml
    Copy File    ${SECRETS_BASE}/python/${DEMO3}/resources/secretstore-vault.yaml    ${dir}/resources/secretstore-vault.yaml
    ${result}=    Run Process
    ...    dapr run --app-id duplicate --dapr-http-port 3500 --resources-path resources -- sleep 1
    ...    shell=True    cwd=${dir}    stderr=STDOUT    timeout=60s
    Should Contain    ${result.stdout}    duplicate definition of Component name secretstore

The Vault Component Is The Same In Every Language
    [Tags]    component
    ${dotnet}=    Get File    ${SECRETS_BASE}/dotnet/${DEMO3}/resources/secretstore-vault.yaml
    ${python}=    Get File    ${SECRETS_BASE}/python/${DEMO3}/resources/secretstore-vault.yaml
    ${java}=    Get File    ${SECRETS_BASE}/java/${DEMO3}/resources/secretstore-vault.yaml
    Should Be Equal    ${dotnet}    ${python}
    Should Be Equal    ${java}    ${python}
    Should Contain    ${python}    name: secretstore
    Should Contain    ${python}    type: secretstores.hashicorp.vault
    Should Contain    ${python}    value: http://localhost:8200
    Should Contain    ${python}    value: root
    # The state store component is a copy of the shared one, so it cannot drift from it.
    FOR    ${lang}    IN    dotnet    python    java
        ${shared}=    Get File    ${SECRETS_BASE}/${lang}/resources/statestore-with-secretref.yaml
        ${copy}=    Get File    ${SECRETS_BASE}/${lang}/${DEMO3}/resources/statestore-with-secretref.yaml
        Should Be Equal    ${copy}    ${shared}
        # The swap folder runs the app that is already there, with its own port and app id.
        ${run}=    Get File    ${SECRETS_BASE}/${lang}/${DEMO3}/dapr.yaml
        ${demo1_run}=    Get File    ${SECRETS_BASE}/${lang}/${DEMO1}/dapr.yaml
        Should Contain    ${run}    appDirPath: ../${DEMO1}
        Should Contain    ${run}    resourcesPath: ./resources
        ${command}=    Evaluate    [l for l in $demo1_run.splitlines() if "command:" in l][0]
        Should Contain    ${run}    ${command}
    END

The Swap Folder Holds No Application Code
    [Documentation]    The claim "the application did not change" rests on Demo3-SwapProvider being
    ...    configuration only: its dapr.yaml starts the app that is already in Demo1-ReadSecret. If
    ...    anyone adds code there, the swap is no longer the same app and this test fails.
    [Tags]    component
    FOR    ${lang}    IN    dotnet    python    java
        @{entries}=    List Directory    ${SECRETS_BASE}/${lang}/${DEMO3}
        # Run output (.dapr) is ignored by git and is not part of the folder.
        ${entries}=    Evaluate    sorted(e for e in $entries if e != ".dapr")
        Should Be Equal    ${{",".join($entries)}}    dapr.yaml,resources
        @{resources}=    List Directory    ${SECRETS_BASE}/${lang}/${DEMO3}/resources
        Should Be Equal    ${{",".join(sorted($resources))}}    secretstore-vault.yaml,statestore-with-secretref.yaml
    END

DotNet The Same App Reads From Vault
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Swap Teardown
    Run And Expect RC Zero    dotnet build    ${SECRETS_BASE}/dotnet/${DEMO1}
    Walk Through The Swap    dotnet

Python The Same App Reads From Vault
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Swap Teardown
    Run And Expect RC Zero    uv sync    ${SECRETS_BASE}/python/${DEMO1}
    Walk Through The Swap    python

Java The Same App Reads From Vault
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Swap Teardown
    Run And Expect RC Zero    mvn -q -DskipTests package    ${SECRETS_BASE}/java/${DEMO1}
    Walk Through The Swap    java    timeout=300s

A Secret In Vault Reaches A Component Through SecretKeyRef
    [Documentation]    The value-level proof for the cross-component interaction. The shared state
    ...    store reads its password from `orderdb-password`, and Vault holds that too, so a log line
    ...    alone cannot show WHERE it was read. Here keyPrefix comes from `state-prefix`, a secret
    ...    that exists only in Vault: Redis stores the key under that prefix, so the value
    ...    crossed from Vault into the component.
    [Tags]    component    value
    [Setup]    Vault Proof Setup
    [Teardown]    Finish Vault Proof
    Vault Proof Starts    state-prefix
    Save A Proof Value Through The Sidecar
    ${keys}=    Capture Command Output    docker exec dapr_redis redis-cli KEYS '*ref-proof*'
    Should Contain    ${keys}    prefix-from-vault||ref-proof

A Missing Secret In Vault Leaves The Component Value Empty
    [Documentation]    Negative control for the test above: the same observation with a reference
    ...    to a name Vault does not have must come out differently, and the sidecar must log it.
    [Tags]    component    value    control
    [Setup]    Vault Proof Setup
    [Teardown]    Finish Vault Proof
    Vault Proof Starts    ${MISSING_NAME}
    Save A Proof Value Through The Sidecar
    ${keys}=    Capture Command Output    docker exec dapr_redis redis-cli KEYS '*ref-proof*'
    Should Contain    ${keys}    ||ref-proof
    Should Not Contain    ${keys}    prefix-from-vault||ref-proof
    Wait Until Log Contains    ${LOG}    ${SECRET_ERROR_LOG}    30s

Solve Script Satisfies The Check Script
    [Documentation]    A check that cannot fail, or a solve that does not satisfy it, would block
    ...    or mislead every learner. Instruqt provides `fail-message`; a stand-in on PATH prints its
    ...    text and exits 1. The apps are left running after the check, as they are for a learner:
    ...    the last instruction of the assignment is to run Check BEFORE stopping them.
    [Tags]    solve    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Solve Teardown
    # Nothing runs: the check must fail, and say so.
    ${idle}=    Run Check Script
    Should Not Be Equal As Integers    ${idle.rc}    0
    Should Contain    ${idle.stdout}    does not answer on port 5001
    # The app runs against the local file: the check must fail with the Vault hint.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${SECRETS_BASE}/dotnet/${DEMO1}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5001/secret/orderdb-password    ${ORDERDB_JSON}    180s
    ${before}=    Run Check Script
    Should Not Be Equal As Integers    ${before.rc}    0
    Should Contain    ${before.stdout}    The app isn't reading from Vault yet
    ${solved}=    Run Process    bash    ${CH_DIR}/scripts/solve.sh    stderr=STDOUT    timeout=300s
    ...    env:TRACKS_SRC_DIR=${TRACKS_SRC_DIR}
    Should Be Equal As Integers    ${solved.rc}    0    msg=solve.sh failed:\n${solved.stdout}
    ${after}=    Run Check Script
    Should Be Equal As Integers    ${after.rc}    0    msg=check.sh failed after solve.sh:\n${after.stdout}
    # And again: the check does not consume or stop anything, so it can be clicked twice.
    ${again}=    Run Check Script
    Should Be Equal As Integers    ${again.rc}    0    msg=check.sh failed the second time:\n${again.stdout}

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

Fingerprint
    [Documentation]    "<sha256>  <path>" for every source file of Demo1-ReadSecret, sorted. Kept
    ...    as text, not as one hash, so a failing comparison shows which file differs.
    [Arguments]    ${lang}
    ${out}=    Capture Command Output    ${FINGERPRINT}    ${SECRETS_BASE}/${lang}
    Should Contain    ${out}    ${DEMO1}/dapr.yaml
    RETURN    ${out}

Store Type Is
    [Arguments]    ${type}
    ${out}=    Capture Command Output    curl -s http://localhost:3500/v1.0/metadata
    Should Contain    ${out}    ${type}

Walk Through The Swap
    [Arguments]    ${lang}    ${timeout}=180s
    ${app_dir}=    Set Variable    ${SECRETS_BASE}/${lang}/${DEMO1}
    ${swap_dir}=    Set Variable    ${SECRETS_BASE}/${lang}/${DEMO3}
    File Should Exist    ${swap_dir}/resources/secretstore-vault.yaml
    ...    msg=${swap_dir}/resources/secretstore-vault.yaml does not exist
    ${before}=    Fingerprint    ${lang}
    # A secret that only Vault has, created the way the assignment creates it.
    Run And Expect RC Zero    ${VAULT_CLI} kv put secret/dapr/shipping-token shipping-token=from-vault

    # 1. The app as challenges 1 and 2 ran it: the local file store.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${app_dir}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5001/secret/orderdb-password    ${ORDERDB_JSON}    ${timeout}
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/metadata | grep -o '"name":"secretstore","type":"[^"]*"'
    ...    ${LOCAL_TYPE}
    # The local file has never heard of the Vault-only secret.
    ${only}=    Request    http://localhost:5001/secret/shipping-token
    Should Be Equal    ${only}[body]    ${VAULT_ONLY_MISSING}
    Should Be Equal    ${only}[status]    ${MISSING_STATUS}
    Stop Process With SIGINT    app
    Wait For The Ports To Be Free
    ${between}=    Fingerprint    ${lang}
    Should Be Equal    ${between}    ${before}

    # 2. The same app, started from the folder whose component is Vault. Nothing was rebuilt.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${swap_dir}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5001/secret/orderdb-password    ${ORDERDB_JSON}    ${timeout}
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/metadata | grep -o '"name":"secretstore","type":"[^"]*"'
    ...    ${VAULT_TYPE}
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/metadata | grep -o '"name":"statestore","type":"[^"]*"'
    ...    ${STATESTORE_TYPE}
    ${local_gone}=    Capture Command Output    curl -s http://localhost:3500/v1.0/metadata
    Should Not Contain    ${local_gone}    secretstores.local.file

    # 3. Same answers, same error contract, now from Vault.
    ${payments}=    Request    http://localhost:5001/secret/payments-api-key
    Should Be Equal    ${payments}[body]    ${PAYMENTS_JSON}
    Should Be Equal    ${payments}[status]    200
    Assert Command Output Contains    curl -s http://localhost:5001/secrets    ${BULK_JSON}
    ${missing}=    Request    http://localhost:5001/secret/legacy-api-key
    Should Be Equal    ${missing}[body]    ${APP_MISSING}
    Should Be Equal    ${missing}[status]    ${MISSING_STATUS}
    # The raw sidecar surface answers the same way it did for the local file store.
    Assert Command Output Contains
    ...    curl -s http://localhost:3500/v1.0/secrets/secretstore/orderdb-password    "orderdb-password":"s3cr3t-pa55w0rd"
    # The secret that only Vault has is readable, and a secret changed in Vault is read fresh
    # (the sidecar does not cache), neither of which a file could show.
    Assert Command Output Contains    curl -s http://localhost:5001/secret/shipping-token    ${VAULT_ONLY_JSON}
    Run And Expect RC Zero    ${VAULT_CLI} kv put secret/dapr/shipping-token shipping-token=rotated
    Assert Command Output Contains    curl -s http://localhost:5001/secret/shipping-token    "value":"rotated"

    # 4. The state store, whose password reference is resolved through `secretstore`, still works
    # and its reference found `orderdb-password` in Vault: no failed lookup in this run's log.
    Run And Expect RC Zero
    ...    curl -s -X POST -H "Content-Type: application/json" -d '[{"key":"order-1","value":"queued"}]' http://localhost:3500/v1.0/state/statestore
    Assert Command Output Contains    curl -s http://localhost:3500/v1.0/state/statestore/order-1    "queued"
    ${log}=    Read Newest Sidecar Log    ${app_dir}
    Should Contain    ${log}    ${STATESTORE_LOADED}
    Should Contain    ${log}    Component loaded: secretstore (secretstores.hashicorp.vault/v1)
    Should Not Contain    ${log}    ${SECRET_ERROR_LOG}
    Should Not Contain    ${log}    ${STORE_NOT_LOADED}

    # 5. Nothing under Demo1-ReadSecret differs between the local file run and the Vault run.
    Stop Process With SIGINT    app
    ${after}=    Fingerprint    ${lang}
    Should Be Equal    ${after}    ${before}

Request
    [Documentation]    GET a URL and return a dictionary with the response body and HTTP status.
    ...    `\%` keeps Robot from reading curl's %{http_code} as an environment variable, and
    ...    the doubled backslash hands curl a literal backslash-n.
    [Arguments]    ${url}
    ${out}=    Capture Command Output    curl -s -w ' \%{http_code}\\n' ${url}
    ${parts}=    Evaluate    $out.rsplit(" ", 1)
    ${response}=    Create Dictionary    body=${parts}[0]    status=${parts}[1]
    RETURN    ${response}

Read Newest Sidecar Log
    # A multi-app run writes the sidecar log to .dapr/logs under the app folder (appDirPath), also
    # when it was started from another folder, as Demo3-SwapProvider does.
    [Arguments]    ${cwd}
    ${log}=    Capture Command Output
    ...    cat "$(ls -t .dapr/logs/order-api_daprd_*.log | head -1)"    ${cwd}
    RETURN    ${log}

Delete Vault Test Secrets
    Run Process    ${VAULT_CLI} kv metadata delete secret/dapr/shipping-token    shell=True
    Run Process    ${VAULT_CLI} kv metadata delete secret/dapr/state-prefix    shell=True

Swap Teardown
    Run Keyword And Ignore Error    Stop Process With SIGINT    app
    Delete Vault Test Secrets

Vault Proof Setup
    Run Process    docker exec dapr_redis redis-cli DEL ${PROOF_KEYS}    shell=True
    Run And Expect RC Zero    ${VAULT_CLI} kv put secret/dapr/state-prefix state-prefix=prefix-from-vault
    Wait For The Ports To Be Free

Vault Proof Starts
    # A throwaway sidecar: the real Vault component, and a Redis state store whose keyPrefix is
    # taken from the secret named by the argument (name and key are the same text, as in the real
    # component). The default app id would also be a Redis prefix, so it is fixed.
    [Arguments]    ${secret_name}
    ${dir}=    Set Variable    ${CONTROL_ROOT}/vault-proof
    Remove Directory    ${dir}    recursive=True
    Create Directory    ${dir}/resources
    Copy File    ${SECRETS_BASE}/python/${DEMO3}/resources/secretstore-vault.yaml    ${dir}/resources/secretstore-vault.yaml
    ${state}=    Catenate    {"apiVersion": "dapr.io/v1alpha1", "kind": "Component",
    ...    "metadata": {"name": "statestore"}, "spec": {"type": "state.redis", "version": "v1",
    ...    "metadata": [{"name": "redisHost", "value": "localhost:6379"},
    ...    {"name": "keyPrefix", "secretKeyRef": {"name": "${secret_name}", "key": "${secret_name}"}}]},
    ...    "auth": {"secretStore": "secretstore"}}
    Create File    ${dir}/resources/statestore.yaml    ${state}
    Start Background Process
    ...    dapr run --app-id vault-proof --dapr-http-port 3500 --resources-path resources -- sleep 300
    ...    ${LOG}    control    cwd=${dir}

Save A Proof Value Through The Sidecar
    Wait Until Keyword Succeeds    60s    2s    Run And Expect RC Zero
    ...    curl -s -f -X POST -H "Content-Type: application/json" -d '[{"key":"ref-proof","value":"from-vault"}]' http://localhost:3500/v1.0/state/statestore

Finish Vault Proof
    Run Keyword And Ignore Error    Stop Process With SIGINT    control
    Run Process    docker exec dapr_redis redis-cli DEL ${PROOF_KEYS}    shell=True
    Delete Vault Test Secrets

Run Check Script
    # fail-message comes from Instruqt; the stand-in prints its text and exits 1.
    ${shim_dir}=    Set Variable    ${TEMPDIR}/dapr-secrets-ch4-shim
    Create Directory    ${shim_dir}
    Create File    ${shim_dir}/fail-message    \#!/bin/bash\necho "FAIL-MESSAGE: $*"\nexit 1\n
    Run Process    chmod    +x    ${shim_dir}/fail-message
    ${result}=    Run Process    bash    ${CH_DIR}/scripts/check.sh    stderr=STDOUT    timeout=120s
    ...    env:PATH=${shim_dir}:%{PATH}    env:TRACKS_SRC_DIR=${TRACKS_SRC_DIR}
    RETURN    ${result}

Solve Teardown
    # solve.sh starts the .NET app itself, in the background, so stop it through dapr.
    Run Keyword And Ignore Error    Stop Process With SIGINT    app
    Run Process    dapr stop -f .    shell=True    cwd=${SECRETS_BASE}/dotnet/${DEMO3}    timeout=60s
    Run Process    dapr stop -f .    shell=True    cwd=${SECRETS_BASE}/dotnet/${DEMO1}    timeout=60s
    Wait For The Ports To Be Free

# doc-sync coverage (expressed via cwd, cwd-relative paths and the Request keyword above):
#   cd dotnet/Demo3-SwapProvider
#   cd python/Demo3-SwapProvider
#   cd java/Demo3-SwapProvider
#   dapr run -f .                  (Walk Through The Swap, cwd = the swap folder)
#   curl -s -w ' %{http_code}\n' http://localhost:5001/secret/shipping-token
#   curl -s -w ' %{http_code}\n' http://localhost:5001/secret/legacy-api-key
#   docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=root vault vault kv put secret/dapr/shipping-token shipping-token=from-vault
