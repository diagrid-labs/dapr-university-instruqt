*** Settings ***
Name              Ch4 Subspace Beacon
Documentation     Drift test for dapr-bindings page 4: demo 4 runs `engineering` and `subspace-beacon`.
...               The `beacon-ping` cron binding (every 5 s, scoped to engineering) makes engineering
...               call the beacon by app ID with service invocation and insert each answer into
...               `comms_log` through `ship-db`. The signal firms up (12, 27, 45, 63, 81, 94) and
...               GET /comms/status turns from SEARCHING to ESTABLISHED. The beacon's sidecar does not
...               load `beacon-ping`.
...
...               Needs bindings-postgres (ci/setup-dapr-bindings.sh starts it). Log lines are read from
...               the `dapr run` output, so only the message is matched.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_bindings.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-bindings-ch4.log
@{PORTS}            5201    5202    3520    3521

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    @{PORTS}
        Port Should Be Free    ${port}
    END

DotNet Engineering Reaches The Beacon
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${BINDINGS_BASE}/dotnet/${DEMO4}[dotnet]/${ENGINEERING}[dotnet]
    Run And Expect RC Zero    dotnet build    ${BINDINGS_BASE}/dotnet/${DEMO4}[dotnet]/${SUBSPACE_BEACON}[dotnet]
    Walk Through Subspace Beacon    dotnet

Python Engineering Reaches The Beacon
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${BINDINGS_BASE}/python/${DEMO4}[python]/${ENGINEERING}[python]
    Run And Expect RC Zero    uv sync    ${BINDINGS_BASE}/python/${DEMO4}[python]/${SUBSPACE_BEACON}[python]
    Walk Through Subspace Beacon    python

Java Engineering Reaches The Beacon
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${BINDINGS_BASE}/java/${DEMO4}[java]/${ENGINEERING}[java]
    Run And Expect RC Zero    mvn -q -DskipTests package    ${BINDINGS_BASE}/java/${DEMO4}[java]/${SUBSPACE_BEACON}[java]
    Walk Through Subspace Beacon    java    timeout=300s    established=180s

*** Keywords ***
Port Should Be Free
    [Arguments]    ${port}
    # curl exits 7 (connection refused) when nothing is listening. rc 0 means something answered.
    ${result}=    Run Process    curl -s -o /dev/null http://localhost:${port}/    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port ${port}. Stop the leaked app before running this suite.

Wait For The Ports To Be Free
    # The previous test's apps can take a moment to release the ports after SIGINT.
    FOR    ${port}    IN    @{PORTS}
        Wait Until Keyword Succeeds    30s    1s    Port Should Be Free    ${port}
    END

Walk Through Subspace Beacon
    [Arguments]    ${lang}    ${timeout}=180s    ${established}=90s
    ${demo_dir}=    Set Variable    ${BINDINGS_BASE}/${lang}/${DEMO4}[${lang}]

    # 2. Run the demo: two apps, two sidecars.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5201/    ${timeout}
    Wait Until App Responds    http://localhost:5202/    ${timeout}
    Wait Until Log Contains    ${LOG}    engineering cleared comms_log for a fresh run    ${timeout}

    # 3. Only engineering's sidecar loads the scoped cron binding; both load ship-db.
    ${beacon_components}=    Capture Command Output    curl -s http://localhost:3521/v1.0/metadata | jq '.components'
    Should Not Contain    ${beacon_components}    beacon-ping
    Should Contain    ${beacon_components}    ship-db
    ${engineering_components}=    Capture Command Output    curl -s http://localhost:3520/v1.0/metadata | jq '.components'
    Should Contain    ${engineering_components}    beacon-ping

    # 4. The signal firms up until the channel opens, then GET /comms/status says ESTABLISHED.
    Wait Until Log Contains    ${LOG}    engineering pinged relay-theta-9 signalStrength=12 message="static"    ${established}
    Wait Until Command Output Contains    curl -s http://localhost:5201/comms/status | jq    "status": "ESTABLISHED"    ${established}
    Wait Until Log Contains    ${LOG}    signalStrength=94 message="channel open"    60s
    ${ping}=    Capture Command Output    curl -s http://localhost:5202/ping | jq
    Should Contain    ${ping}    "beaconId": "relay-theta-9"
    Should Contain    ${ping}    "signalStrength": 94

    # 5. Every answer is a row in comms_log.
    ${rows}=    Capture Command Output    ${PSQL} -c "SELECT * FROM comms_log;"
    Should Contain    ${rows}    channel open
    ${count}=    Capture Command Output    ${PSQL} -tAc "SELECT count(*) FROM comms_log"
    Should Be True    ${count} >= 6

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder):
#   cd /root/university-labs/bindings
#   cd dotnet/Demo4-SubspaceBeacon
#   cd python/demo4-subspace-beacon
#   cd java/demo4-subspace-beacon
#   dapr run -f .
#   docker exec bindings-postgres psql -U dapr -d dapr -c "SELECT * FROM comms_log;"
