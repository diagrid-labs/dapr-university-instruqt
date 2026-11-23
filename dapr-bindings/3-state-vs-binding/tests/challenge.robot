*** Settings ***
Name              Ch3 State API vs Binding
Documentation     Drift test for dapr-bindings page 3: demo 3 saves each reading twice into the same
...               database, through the State API (`statestore`, `state.postgresql`) and through the
...               `ship-db` binding. GET /state/<id> reads by key, GET /readings runs the app's SQL,
...               and both return the reading this run logged.
...
...               The `state` table is not cleared between runs: its keys are overwritten. So after
...               another language ran first, /state/wc-0001 must still return the reading of the
...               current run (Review Focus 4), which the suite checks against the scan log line.
...
...               Needs bindings-postgres (ci/setup-dapr-bindings.sh starts it). Log lines are read from
...               the `dapr run` output, so only the message is matched.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_bindings.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-bindings-ch3.log

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5201    3520
        Port Should Be Free    ${port}
    END

The Binding Table Has The Schema From init.sql
    ${table}=    Capture Command Output    ${PSQL} -c "\\d warp_core_readings"
    FOR    ${column}    IN    reading_id    stardate    core_temp_k    plasma_flow    recorded_at
        Should Contain    ${table}    ${column}
    END

DotNet Reading Is Saved Through Both APIs
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT If Running    app
    Run And Expect RC Zero    dotnet build    ${BINDINGS_BASE}/dotnet/${DEMO3}[dotnet]/${ENGINEERING}[dotnet]
    Walk Through State Vs Binding    dotnet

Python Reading Is Saved Through Both APIs
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT If Running    app
    Run And Expect RC Zero    uv sync    ${BINDINGS_BASE}/python/${DEMO3}[python]/${ENGINEERING}[python]
    Walk Through State Vs Binding    python

Java Reading Is Saved Through Both APIs
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT If Running    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${BINDINGS_BASE}/java/${DEMO3}[java]/${ENGINEERING}[java]
    Walk Through State Vs Binding    java    timeout=300s

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

Walk Through State Vs Binding
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${BINDINGS_BASE}/${lang}/${DEMO3}[${lang}]

    # 2. Run the demo. Wait for both writes of wc-0001 by this run.
    Start Background Process    exec dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5201/    ${timeout}
    Wait Until Log Contains    ${LOG}    engineering saved reading wc-0001 to statestore (key=reading-wc-0001)    ${timeout}
    Wait Until Log Contains    ${LOG}    engineering stored reading wc-0001 in warp_core_readings    60s
    ${scan}=    Grep File    ${LOG}    engineering warp-core scan wc-0001
    ${temps}=    Get Regexp Matches    ${scan}    coreTempK=(\\d+)    1
    ${logged_temp}=    Set Variable    ${temps}[0]

    # 3. Read it back through each API. Both return the reading this run logged.
    ${state}=    Capture Command Output    curl -s http://localhost:5201/state/wc-0001 | jq
    Should Contain    ${state}    "readingId": "wc-0001"
    ${state_temp}=    Capture Command Output    curl -s http://localhost:5201/state/wc-0001 | jq '.coreTempK'
    Should Be Equal    ${state_temp}    ${logged_temp}    msg=/state/wc-0001 does not return this run's reading.
    ${row}=    Capture Command Output
    ...    curl -s "http://localhost:5201/readings" | jq '.[] | select(.readingId == "wc-0001")'
    Should Contain    ${row}    "coreTempK": ${logged_temp}
    Should Contain    ${row}    "recordedAt"
    ${missing}=    Capture Command Output    curl -s -w ' \%{http_code}' http://localhost:5201/state/nope
    Should Contain    ${missing}    NOT_FOUND
    Should End With    ${missing}    404

    # 4. Compare the two tables. Dapr owns `state` and prefixes keys with the app ID.
    ${state_table}=    Capture Command Output    ${PSQL} -c "\\d state"
    Should Contain    ${state_table}    key
    Should Contain    ${state_table}    jsonb
    ${rows}=    Capture Command Output    ${PSQL} -c "SELECT key, value FROM state ORDER BY key LIMIT 2;"
    Should Contain    ${rows}    engineering||reading-wc-0001
    ${key}=    Capture Command Output    ${PSQL} -tAc "SELECT count(*) FROM state WHERE key = 'engineering||reading-wc-0001'"
    Should Be Equal    ${key}    1

    # Review Focus 4, in every CI leg: run the demo again in the same language. The state table
    # still holds the first run's wc-0001; the new run must overwrite it with its own reading.
    Stop Process With SIGINT    app
    Wait For The Ports To Be Free
    Start Background Process    exec dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5201/    ${timeout}
    Wait Until Log Contains    ${LOG}    engineering saved reading wc-0001 to statestore (key=reading-wc-0001)    ${timeout}
    ${scan}=    Grep File    ${LOG}    engineering warp-core scan wc-0001
    ${temps}=    Get Regexp Matches    ${scan}    coreTempK=(\\d+)    1
    ${state_temp}=    Capture Command Output    curl -s http://localhost:5201/state/wc-0001 | jq '.coreTempK'
    Should Be Equal    ${state_temp}    ${temps}[0]    msg=The second run's /state/wc-0001 still returns the first run's reading.

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder, or with psql's backslash commands escaped for Robot):
#   cd /root/university-labs/bindings
#   cd dotnet/Demo3-StateVsBinding
#   cd python/demo3-state-vs-binding
#   cd java/demo3-state-vs-binding
#   dapr run -f .
#   docker exec bindings-postgres psql -U dapr -d dapr -c "\d state"
#   docker exec bindings-postgres psql -U dapr -d dapr -c "\d warp_core_readings"
#   docker exec bindings-postgres psql -U dapr -d dapr -c "SELECT key, value FROM state ORDER BY key LIMIT 2;"
