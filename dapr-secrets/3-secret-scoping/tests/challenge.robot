*** Settings ***
Name              Ch3 Secret Scoping
Documentation     Drift test for dapr-secrets challenge 3, the track's aha moment: App A reads a
...               secret, App B asks for the same secret and is refused. Per language it walks the
...               assignment: both apps read the secret with no scoping, then app-b's Configuration
...               is switched on and app-b is told no while app-a is not.
...
...               This suite owns the denial regression guard. Challenge 1's apps have a 403 branch
...               that only a scoping Configuration can trigger, so this is the only automated
...               coverage that branch has in .NET, Python and Java.
...
...               There are two response surfaces and they use different strings. The raw sidecar
...               answers ERR_PERMISSION_DENIED / ERR_SECRET_GET (DENIED_BODY / MISSING_BODY), the
...               demo apps answer PERMISSION_DENIED / INTERNAL (APP_DENIED_ERROR /
...               APP_MISSING_ERROR). ERR_PERMISSION_DENIED contains PERMISSION_DENIED, so a
...               `contains` check against the wrong surface would pass and prove nothing. The app
...               surface is therefore compared with Should Be Equal, never with a substring.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_secrets.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}                ${TEMPDIR}/dapr-secrets-ch3.log
${LOG_CONTROL}        ${TEMPDIR}/dapr-secrets-ch3-control.log
${LOG_SOLVE}          ${TEMPDIR}/dapr-secrets-ch3-solve.log
${CH_DIR}             ${CURDIR}/..
# The values secrets.example.json (the single owner of the demo values) holds.
${ORDERDB_JSON}       {"name":"orderdb-password","value":"s3cr3t-pa55w0rd"}
${PAYMENTS_JSON}      {"name":"payments-api-key","value":"pk-test-7f3a9"}
# What the demo apps answer (the app surface): "name" first, the gRPC status name as the error.
${APP_DENIED}         {"name":"orderdb-password","error":"${APP_DENIED_ERROR}"}
${APP_MISSING}        {"name":"legacy-api-key","error":"${APP_MISSING_ERROR}"}
# An unlisted name that is not in the store either. Scoping answers it with the same denial.
${APP_UNKNOWN}        {"name":"does-not-exist","error":"${APP_DENIED_ERROR}"}
# Daprd 1.18.x log wording, as in challenge 2: pinned here so a runtime change fails the suite.
${SECRET_ERROR_LOG}      Error getting secret
${STORE_LOADED_LOG}      Component loaded: secretstore

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    Port Should Be Free    5002
    Port Should Be Free    5003

DotNet App B Is Refused A Secret App A Can Read
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Scoping Teardown
    Run And Expect RC Zero    dotnet build    ${SECRETS_BASE}/dotnet/${DEMO2}/AppA
    Run And Expect RC Zero    dotnet build    ${SECRETS_BASE}/dotnet/${DEMO2}/AppB
    Walk Through The Scoping Story    ${SECRETS_BASE}/dotnet/${DEMO2}

Python App B Is Refused A Secret App A Can Read
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Scoping Teardown
    Run And Expect RC Zero    uv sync    ${SECRETS_BASE}/python/${DEMO2}/AppA
    Run And Expect RC Zero    uv sync    ${SECRETS_BASE}/python/${DEMO2}/AppB
    Walk Through The Scoping Story    ${SECRETS_BASE}/python/${DEMO2}

Java App B Is Refused A Secret App A Can Read
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Scoping Teardown
    Run And Expect RC Zero    mvn -q -DskipTests package    ${SECRETS_BASE}/java/${DEMO2}/AppA
    Run And Expect RC Zero    mvn -q -DskipTests package    ${SECRETS_BASE}/java/${DEMO2}/AppB
    Walk Through The Scoping Story    ${SECRETS_BASE}/java/${DEMO2}    timeout=300s

DotNet The Deny List Direction Refuses The Same Secret
    [Documentation]    The assignment's last step, step 8: defaultAccess allow with deniedSecrets.
    ...    The sidecar behaviour does not depend on the language, so one language is enough.
    [Tags]    dotnet    denylist
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Scoping Teardown
    ${demo_dir}=    Set Variable    ${SECRETS_BASE}/dotnet/${DEMO2}
    Restore Dapr Yaml Files
    Copy File    ${demo_dir}/dapr.yaml    ${demo_dir}/dapr.yaml.suite-bak
    Copy File    ${demo_dir}/resources/config-app-b.yaml    ${demo_dir}/resources/config-app-b.yaml.suite-bak
    Remove Hash In Front Of Config File Path    ${demo_dir}/dapr.yaml
    ${config}=    Get File    ${demo_dir}/resources/config-app-b.yaml
    ${config}=    Replace String    ${config}    defaultAccess: deny    defaultAccess: allow
    ${config}=    Replace String    ${config}    allowedSecrets: ["payments-api-key", "legacy-api-key"]
    ...    deniedSecrets: ["orderdb-password"]
    Should Contain    ${config}    deniedSecrets: ["orderdb-password"]
    Create File    ${demo_dir}/resources/config-app-b.yaml    ${config}
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5003/secret/payments-api-key    ${PAYMENTS_JSON}    180s
    ${denied}=    Request    http://localhost:5003/secret/orderdb-password
    Should Be Equal    ${denied}[body]    ${APP_DENIED}
    Should Be Equal    ${denied}[status]    ${DENIED_STATUS}
    ${allowed}=    Request    http://localhost:5003/secret/payments-api-key
    Should Be Equal    ${allowed}[body]    ${PAYMENTS_JSON}
    Should Be Equal    ${allowed}[status]    200

# Characterization, not a guard. The shared per-language resources folder holds
# statestore-with-secretref.yaml, which reads orderdb-password through secretKeyRef, the very
# secret config-app-b.yaml denies. It was expected that a sidecar loading both would log
# "Error getting secret" at startup. Measured on daprd 1.18.7 it does not: scoping applies to the
# Secrets API calls an app makes, not to the lookups the sidecar does itself for a component.
# Demo2-Scoping still has a resources folder of its own (no Redis dependency, no unrelated
# component next to the lesson), but not because of a startup error. If a runtime starts
# applying scoping to secretKeyRef, this test fails and the isolation becomes necessary.
# The clean-startup assertion in the language tests can fire: challenge 2's suite shows the same
# log line appearing for a secretKeyRef that cannot be resolved.

Scoping Does Not Apply To A Component's SecretKeyRef Lookup
    [Tags]    control
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    control
    Start Background Process
    ...    dapr run --app-id app-b --dapr-http-port 3502 --resources-path ../resources --config resources/config-app-b.yaml
    ...    ${LOG_CONTROL}    control    cwd=${SECRETS_BASE}/dotnet/${DEMO2}
    Wait Until Log Contains    ${LOG_CONTROL}    Component loaded: statestore    120s
    ${log}=    Get File    ${LOG_CONTROL}
    Should Not Contain    ${log}    ${SECRET_ERROR_LOG}

# The check.sh / solve.sh pair. A check that cannot fail, or a solve that does not satisfy the
# check, would block or mislead every learner. Instruqt provides `fail-message`; a stand-in on
# PATH prints its text and exits 1. dapr.yaml is edited by solve.sh in all three languages, so
# every copy is restored afterwards.

Solve Script Satisfies The Check Script
    [Tags]    solve    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Solve Teardown
    Restore Dapr Yaml Files
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${SECRETS_BASE}/dotnet/${DEMO2}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5003/secret/orderdb-password    ${ORDERDB_JSON}    180s
    # Before solving: App B can still read the secret, so the check must fail with its hint.
    ${before}=    Run Check Script
    Should Not Be Equal As Integers    ${before.rc}    0
    Should Contain    ${before.stdout}    App B can still read orderdb-password
    ${solved}=    Run Process    bash    ${CH_DIR}/scripts/solve.sh    stderr=STDOUT    timeout=300s
    ...    env:TRACKS_SRC_DIR=${TRACKS_SRC_DIR}
    Should Be Equal As Integers    ${solved.rc}    0    msg=solve.sh failed:\n${solved.stdout}
    ${after}=    Run Check Script
    Should Be Equal As Integers    ${after.rc}    0    msg=check.sh failed after solve.sh:\n${after.stdout}

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
    Wait Until Keyword Succeeds    30s    1s    Port Should Be Free    5002
    Wait Until Keyword Succeeds    30s    1s    Port Should Be Free    5003

Walk Through The Scoping Story
    [Arguments]    ${demo_dir}    ${timeout}=180s
    Restore Dapr Yaml Files
    Copy File    ${demo_dir}/dapr.yaml    ${demo_dir}/dapr.yaml.suite-bak

    # 1. Both apps, no scoping on app-b.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5002/secret/orderdb-password    ${ORDERDB_JSON}    ${timeout}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5003/secret/payments-api-key    ${PAYMENTS_JSON}    ${timeout}
    # App A reads the secret, and so does App B: nothing stops it yet.
    ${a}=    Request    http://localhost:5002/secret/orderdb-password
    Should Be Equal    ${a}[body]    ${ORDERDB_JSON}
    Should Be Equal    ${a}[status]    200
    ${b}=    Request    http://localhost:5003/secret/orderdb-password
    Should Be Equal    ${b}[body]    ${ORDERDB_JSON}
    Should Be Equal    ${b}[status]    200

    # 2. Switch app-b's Configuration on, the way the assignment does: remove the # in front of
    # configFilePath in dapr.yaml, then restart.
    Stop Process With SIGINT    app
    Wait For The Ports To Be Free
    Remove Hash In Front Of Config File Path    ${demo_dir}/dapr.yaml
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5002/secret/orderdb-password    ${ORDERDB_JSON}    ${timeout}
    Wait Until Command Output Contains
    ...    curl -s http://localhost:5003/secret/payments-api-key    ${PAYMENTS_JSON}    ${timeout}

    # 3. Exactly one failure is on screen: before anything is asked of app-b, its sidecar has
    # loaded the secret store without a single failed secret lookup.
    ${sidecar_log}=    Read Newest Sidecar Log    ${demo_dir}/AppB    app-b
    Should Contain    ${sidecar_log}    ${STORE_LOADED_LOG}
    Should Not Contain    ${sidecar_log}    ${SECRET_ERROR_LOG}

    # 4. The refusal, as the learner sees it through the app (the app surface).
    ${denied}=    Request    http://localhost:5003/secret/orderdb-password
    Should Be Equal    ${denied}[body]    ${APP_DENIED}
    Should Be Equal    ${denied}[status]    ${DENIED_STATUS}
    # The app string has no ERR_ prefix. Equality above already proves it; this makes the trap
    # visible: the sidecar's string must never be what an app returns.
    Should Not Contain    ${denied}[body]    ${DENIED_BODY}

    # 5. The same refusal, straight from App B's sidecar (the sidecar surface).
    ${raw_denied}=    Request    http://localhost:3502/v1.0/secrets/secretstore/orderdb-password
    Should Be Equal    ${raw_denied}[status]    ${DENIED_STATUS}
    Should Contain    ${raw_denied}[body]    "errorCode":"${DENIED_BODY}"
    Should Not Contain    ${raw_denied}[body]    ${APP_MISSING_ERROR}

    # 6. Allowed and present: App B still reads payments-api-key.
    ${allowed}=    Request    http://localhost:5003/secret/payments-api-key
    Should Be Equal    ${allowed}[body]    ${PAYMENTS_JSON}
    Should Be Equal    ${allowed}[status]    200

    # 7. Allowed but absent: legacy-api-key is in allowedSecrets and not in the store. The
    # failure must differ from the denial, on both surfaces, in status and in text.
    ${missing}=    Request    http://localhost:5003/secret/legacy-api-key
    Should Be Equal    ${missing}[body]    ${APP_MISSING}
    Should Be Equal    ${missing}[status]    ${MISSING_STATUS}
    ${raw_missing}=    Request    http://localhost:3502/v1.0/secrets/secretstore/legacy-api-key
    Should Be Equal    ${raw_missing}[status]    ${MISSING_STATUS}
    Should Contain    ${raw_missing}[body]    "errorCode":"${MISSING_BODY}"
    Should Not Be Equal    ${missing}[status]    ${denied}[status]
    Should Not Be Equal    ${raw_missing}[status]    ${raw_denied}[status]
    Should Not Be Equal    ${missing}[body]    ${denied}[body]
    Should Not Contain    ${raw_missing}[body]    ${DENIED_BODY}

    # 8. Scoping does not tell you what exists: a name that is nowhere in the store is refused
    # exactly like the real secret, because the scope check runs before the lookup.
    ${unknown}=    Request    http://localhost:5003/secret/does-not-exist
    Should Be Equal    ${unknown}[body]    ${APP_UNKNOWN}
    Should Be Equal    ${unknown}[status]    ${DENIED_STATUS}

    # 9. App A, same secret, other sidecar: still allowed. Only the configuration differs.
    ${a_after}=    Request    http://localhost:5002/secret/orderdb-password
    Should Be Equal    ${a_after}[body]    ${ORDERDB_JSON}
    Should Be Equal    ${a_after}[status]    200
    ${a_raw}=    Request    http://localhost:3501/v1.0/secrets/secretstore/orderdb-password
    Should Be Equal    ${a_raw}[status]    200

Request
    [Documentation]    GET a URL and return a dictionary with the response body and HTTP status.
    ...    The command is the one the assignment shows, so the learner's output is what is asserted.
    ...    `\%` keeps Robot from reading curl's %{http_code} as an environment variable, and
    ...    the doubled backslash hands curl a literal backslash-n.
    [Arguments]    ${url}
    ${out}=    Capture Command Output    curl -s -w ' \%{http_code}\\n' ${url}
    ${parts}=    Evaluate    $out.rsplit(" ", 1)
    ${response}=    Create Dictionary    body=${parts}[0]    status=${parts}[1]
    RETURN    ${response}

Read Newest Sidecar Log
    [Arguments]    ${app_dir}    ${app_id}
    # `dapr run -f .` writes each sidecar's log to <appDirPath>/.dapr/logs, not to the terminal.
    ${log}=    Capture Command Output
    ...    cat "$(ls -t .dapr/logs/${app_id}_daprd_*.log | head -1)"    ${app_dir}
    RETURN    ${log}

Remove Hash In Front Of Config File Path
    [Arguments]    ${file}
    # The edit the learner makes in the Editor tab (and solve.sh makes with sed).
    ${yaml}=    Get File    ${file}
    Should Contain    ${yaml}    \# configFilePath:
    ${edited}=    Replace String    ${yaml}    \# configFilePath:    configFilePath:
    Create File    ${file}    ${edited}

Restore Dapr Yaml Files
    # dapr.yaml is edited in place, so put the committed copy back, including after a crashed run.
    FOR    ${lang}    IN    dotnet    python    java
        ${dir}=    Set Variable    ${SECRETS_BASE}/${lang}/${DEMO2}
        ${has_backup}=    Run Keyword And Return Status    File Should Exist    ${dir}/dapr.yaml.suite-bak
        IF    ${has_backup}
            Move File    ${dir}/dapr.yaml.suite-bak    ${dir}/dapr.yaml
        END
        ${has_backup}=    Run Keyword And Return Status
        ...    File Should Exist    ${dir}/resources/config-app-b.yaml.suite-bak
        IF    ${has_backup}
            Move File    ${dir}/resources/config-app-b.yaml.suite-bak    ${dir}/resources/config-app-b.yaml
        END
    END

Scoping Teardown
    Run Keyword And Ignore Error    Stop Process With SIGINT    app
    Restore Dapr Yaml Files

Run Check Script
    # fail-message comes from Instruqt; the stand-in prints its text and exits 1.
    ${shim_dir}=    Set Variable    ${TEMPDIR}/dapr-secrets-ch3-shim
    Create Directory    ${shim_dir}
    Create File    ${shim_dir}/fail-message    \#!/bin/bash\necho "FAIL-MESSAGE: $*"\nexit 1\n
    Run Process    chmod    +x    ${shim_dir}/fail-message
    ${result}=    Run Process    bash    ${CH_DIR}/scripts/check.sh    stderr=STDOUT    timeout=120s
    ...    env:PATH=${shim_dir}:%{PATH}    env:TRACKS_SRC_DIR=${TRACKS_SRC_DIR}
    RETURN    ${result}

Solve Teardown
    # solve.sh starts the .NET apps itself, in the background, so stop them through dapr.
    Run Keyword And Ignore Error    Stop Process With SIGINT    app
    Run Process    dapr stop -f .    shell=True    cwd=${SECRETS_BASE}/dotnet/${DEMO2}    timeout=60s
    Restore Dapr Yaml Files
    # solve.sh edits every language's dapr.yaml without a backup of its own; undo that too.
    FOR    ${lang}    IN    dotnet    python    java
        ${file}=    Set Variable    ${SECRETS_BASE}/${lang}/${DEMO2}/dapr.yaml
        # Create File would also create a missing folder, so only touch a file that exists.
        IF    os.path.isfile($file)
            ${yaml}=    Get File    ${file}
            ${restored}=    Replace String    ${yaml}    ${SPACE}configFilePath:    ${SPACE}\# configFilePath:
            Create File    ${file}    ${restored}
        END
    END
    Wait For The Ports To Be Free

# doc-sync coverage (the commands are run above through the Request and Start Background Process
# keywords, which build them from the URL and the folder):
#   cd dotnet/Demo2-Scoping
#   cd python/Demo2-Scoping
#   cd java/Demo2-Scoping
#   dapr run -f .
#   curl -s -w ' %{http_code}\n' http://localhost:5002/secret/orderdb-password
#   curl -s -w ' %{http_code}\n' http://localhost:5003/secret/orderdb-password
#   curl -s -w ' %{http_code}\n' http://localhost:5003/secret/payments-api-key
#   curl -s -w ' %{http_code}\n' http://localhost:5003/secret/legacy-api-key
#   curl -s -w ' %{http_code}\n' http://localhost:5003/secret/does-not-exist
#   curl -s -w ' %{http_code}\n' http://localhost:3502/v1.0/secrets/secretstore/orderdb-password
#   curl -s -w ' %{http_code}\n' http://localhost:3502/v1.0/secrets/secretstore/legacy-api-key
