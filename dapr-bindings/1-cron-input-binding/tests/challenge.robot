*** Settings ***
Name              Ch1 Cron Input Binding
Documentation     Drift test for dapr-bindings page 1: demo 1 runs `engineering` with one cron input
...               binding, `warp-core-scan` (`@every 10s`). The sidecar calls POST /warp-core-scan on
...               every tick, so the app logs a numbered warp-core scan without any Dapr code. The
...               sidecar's metadata lists the component as `bindings.cron`, and no `ship-db`.
...
...               The page has the learner change the schedule to `@every 3s` in the Editor. The suite
...               makes that edit on a temporary copy of the demo folder only, and checks that the
...               checkout is left untouched, so a later suite never sees the edited schedule.
...
...               Log lines are read from the `dapr run` output, which has the prefix
...               `== APP - <appID> ==` and, in .NET and Java, a logger prefix too, so only the
...               message is matched.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_bindings.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-bindings-ch1.log
${LOG_FAST}         ${TEMPDIR}/dapr-bindings-ch1-fast.log
${SCAN}             engineering warp-core scan

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5201    3520
        Port Should Be Free    ${port}
    END

DotNet Cron Binding Calls The App
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${BINDINGS_BASE}/dotnet/${DEMO1}[dotnet]/${ENGINEERING}[dotnet]
    Walk Through Cron Input Binding    dotnet

Python Cron Binding Calls The App
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${BINDINGS_BASE}/python/${DEMO1}[python]/${ENGINEERING}[python]
    Walk Through Cron Input Binding    python

Java Cron Binding Calls The App
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${BINDINGS_BASE}/java/${DEMO1}[java]/${ENGINEERING}[java]
    Walk Through Cron Input Binding    java    timeout=300s

*** Keywords ***
Port Should Be Free
    [Arguments]    ${port}
    # curl exits 7 (connection refused) when nothing is listening. rc 0 means something answered.
    ${result}=    Run Process    curl -s -o /dev/null http://localhost:${port}/    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port ${port}. Stop the leaked app before running this suite.

Wait For The Ports To Be Free
    # The previous test's app can take a moment to release the ports after SIGINT.
    FOR    ${port}    IN    5201    3520
        Wait Until Keyword Succeeds    30s    1s    Port Should Be Free    ${port}
    END

Walk Through Cron Input Binding
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${BINDINGS_BASE}/${lang}/${DEMO1}[${lang}]

    # 3. Run the demo. The cron binding waits one full interval before the first tick.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5201/    ${timeout}
    Wait Until Log Contains    ${LOG}    ${SCAN} wc-0001 stardate=    ${timeout}
    # A second scan proves the schedule repeats (10 s apart, with slack).
    Wait Until Log Contains    ${LOG}    ${SCAN} wc-0002 stardate=    25s
    ${line}=    Grep File    ${LOG}    ${SCAN} wc-0001
    Should Match Regexp    ${line}    ${SCAN} wc-0001 stardate=\\d+\\.\\d coreTempK=\\d{3} plasmaFlow=\\d\\.\\d\\d

    # 4. The sidecar lists the cron binding and nothing else: demo 1 loads only its own resources.
    ${components}=    Capture Command Output    curl -s http://localhost:3520/v1.0/metadata | jq '.components'
    Should Contain    ${components}    "name": "warp-core-scan"
    Should Contain    ${components}    "type": "bindings.cron"
    Should Not Contain    ${components}    ship-db
    Stop Process With SIGINT    app
    Wait For The Ports To Be Free

    # 5. The schedule lives in YAML. Edit a copy, never the checkout (Review Focus 3).
    ${copy}=    Set Variable    ${TEMPDIR}/dapr-bindings-ch1-${lang}
    Remove Directory    ${copy}    recursive=True
    Copy Directory    ${demo_dir}    ${copy}
    Remove Directory    ${copy}/.dapr    recursive=True
    ${yaml}=    Set Variable    ${copy}/resources/warp-core-scan.yaml
    ${text}=    Get File    ${yaml}
    ${text}=    Replace String    ${text}    @every 10s    @every 3s
    Create File    ${yaml}    ${text}
    File Should Contain    ${yaml}    value: "@every 3s"
    Start Background Process    dapr run -f .    ${LOG_FAST}    app    cwd=${copy}
    Wait Until App Responds    http://localhost:5201/    ${timeout}
    Wait Until Log Contains    ${LOG_FAST}    ${SCAN} wc-0001 stardate=    ${timeout}
    # Four scans in at most 20 s: at 10 s apart that would take 30 s.
    Wait Until Log Contains    ${LOG_FAST}    ${SCAN} wc-0004 stardate=    20s

    # The checkout still has the original schedule and no tracked change.
    File Should Contain    ${demo_dir}/resources/warp-core-scan.yaml    value: "@every 10s"
    ${status}=    Capture Command Output    git -C ${TRACKS_SRC_DIR} status --porcelain bindings
    Should Be Empty    ${status}

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder; the schedule edit is made on a copy, the page restarts in place):
#   cd /root/university-labs/bindings
#   cd dotnet/Demo1-CronTrigger
#   cd python/demo1-cron-trigger
#   cd java/demo1-cron-trigger
#   dapr run -f .
#   curl -s http://localhost:3520/v1.0/metadata | jq '.components'
