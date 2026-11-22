*** Settings ***
Name              Ch2 PostgreSQL Output Binding
Documentation     Drift test for dapr-bindings page 2: demo 2 runs `engineering` with the shared
...               `ship-db` PostgreSQL output binding and two cron input bindings. At startup the app
...               clears `warp_core_readings`; each scan stores a reading with `exec`, GET /readings
...               reads them with `query`, and `purge-old-readings` deletes rows older than a minute.
...
...               The page's restart block (section "If the database is not running") is read from
...               the assignment and run as is, with the VM path swapped for TRACKS_SRC_DIR: twice in
...               a row, and once while the demo runs, after which the app must store readings again
...               without a restart.
...
...               Needs bindings-postgres (ci/setup-dapr-bindings.sh starts it). Log lines are read from
...               the `dapr run` output, so only the message is matched.
Library           ../../../tools/track-tester/libraries/assignment_blocks.py
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_bindings.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-bindings-ch2.log
${ASSIGNMENT}       ${CURDIR}/../assignment.md
${STORED}           engineering stored reading
${PURGED}           engineering purged old readings

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5201    3520
        Port Should Be Free    ${port}
    END

The Restart Block Is Safe To Run Twice
    [Documentation]    Review Focus 5: a learner can press the button twice; both runs succeed and
    ...    leave both tables in place.
    Run The Restart Block
    Run The Restart Block
    The Bindings Tables Exist

The Database Lists The Bindings Tables
    The Bindings Tables Exist

DotNet Readings Go Through The Output Binding
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build    ${BINDINGS_BASE}/dotnet/${DEMO2}[dotnet]/${ENGINEERING}[dotnet]
    Walk Through Postgres Output Binding    dotnet

Python Readings Go Through The Output Binding
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    uv sync    ${BINDINGS_BASE}/python/${DEMO2}[python]/${ENGINEERING}[python]
    Walk Through Postgres Output Binding    python

Java Readings Go Through The Output Binding
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    mvn -q -DskipTests package    ${BINDINGS_BASE}/java/${DEMO2}[java]/${ENGINEERING}[java]
    Walk Through Postgres Output Binding    java    timeout=300s

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

Run The Restart Block
    # The block exactly as the page shows it; only the VM's checkout path differs in CI.
    ${block}=    Get Run Block Containing    ${ASSIGNMENT}    docker run -d --name bindings-postgres
    ${block}=    Replace String    ${block}    /root/university-labs    ${TRACKS_SRC_DIR}
    ${result}=    Run Process    bash    -c    ${block}    stderr=STDOUT
    Should Be Equal As Integers    ${result.rc}    0    msg=${result.stdout}
    # The block ends by listing the tables, so the learner sees whether it worked.
    Should Contain    ${result.stdout}    warp_core_readings
    Should Contain    ${result.stdout}    comms_log

The Bindings Tables Exist
    ${tables}=    Capture Command Output    ${PSQL} -c "\\dt"
    Should Contain    ${tables}    comms_log
    Should Contain    ${tables}    warp_core_readings

SQL Value
    [Arguments]    ${sql}
    ${value}=    Capture Command Output    ${PSQL} -tAc "${sql}"
    RETURN    ${value}

Log Count Should Exceed
    [Arguments]    ${text}    ${count}
    ${log}=    Get File    ${LOG}
    ${now}=    Get Count    ${log}    ${text}
    Should Be True    ${now} > ${count}    msg=No new "${text}" line (still ${now}).

Count In Log
    [Arguments]    ${text}
    ${log}=    Get File    ${LOG}
    ${count}=    Get Count    ${log}    ${text}
    RETURN    ${count}

Walk Through Postgres Output Binding
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${BINDINGS_BASE}/${lang}/${DEMO2}[${lang}]
    # A leftover row from an earlier run: the app must clear the table at startup.
    SQL Value    INSERT INTO warp_core_readings (reading_id, stardate, core_temp_k, plasma_flow) VALUES ('stale-1', 1.0, 900, 0.80) ON CONFLICT DO NOTHING

    # 3. Run the demo.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5201/    ${timeout}

    # 4. The startup clear, then a stored reading.
    Wait Until Log Contains    ${LOG}    engineering cleared warp_core_readings for a fresh run    ${timeout}
    ${stale}=    SQL Value    SELECT count(*) FROM warp_core_readings WHERE reading_id = 'stale-1'
    Should Be Equal    ${stale}    0
    Wait Until Log Contains    ${LOG}    ${STORED} wc-0001 in warp_core_readings    60s

    ${hot}=    Capture Command Output    curl -s "http://localhost:5201/readings?minTemp=900" | jq
    Should Start With    ${hot}    [
    ${keys}=    Capture Command Output
    ...    curl -s "http://localhost:5201/readings?minTemp=-5" | jq -c '[.[] | select(.readingId == "wc-0001") | keys_unsorted]'
    Should Be Equal    ${keys}    [["readingId","stardate","coreTempK","plasmaFlow","recordedAt"]]
    ${bad}=    Capture Command Output    curl -s -w ' \%{http_code}' "http://localhost:5201/readings?minTemp=abc"
    Should Contain    ${bad}    INVALID_MIN_TEMP
    Should End With    ${bad}    400
    ${rows}=    Capture Command Output    ${PSQL} -c "SELECT * FROM warp_core_readings;"
    Should Contain    ${rows}    wc-0001

    # 6. A row older than a minute goes at the next 30 s purge tick. Count the purge lines first
    # and insert the row already aged, so no tick can see it fresh.
    ${purges_before}=    Count In Log    ${PURGED}
    SQL Value    INSERT INTO warp_core_readings (reading_id, stardate, core_temp_k, plasma_flow, recorded_at) VALUES ('old-1', 1.0, 900, 0.80, now() - interval '2 minutes')
    Wait Until Keyword Succeeds    45s    1s    Log Count Should Exceed    ${PURGED}    ${purges_before}
    Wait Until Keyword Succeeds    45s    1s    SQL Should Return    SELECT count(*) FROM warp_core_readings WHERE reading_id = 'old-1'    0

    # Review Focus 1: the database is recreated while the app runs. The app keeps going and
    # stores readings again without a restart.
    Run The Restart Block
    ${stored_before}=    Count In Log    ${STORED}
    Wait Until Keyword Succeeds    30s    1s    Log Count Should Exceed    ${STORED}    ${stored_before}
    ${fresh}=    SQL Value    SELECT count(*) FROM warp_core_readings
    Should Be True    ${fresh} > 0

SQL Should Return
    [Arguments]    ${sql}    ${expected}
    ${value}=    SQL Value    ${sql}
    Should Be Equal    ${value}    ${expected}

# doc-sync coverage (the commands are run above through keywords that build them from the
# language and the folder, or, for the restart block, read straight from the assignment):
#   cd /root/university-labs/bindings
#   cd dotnet/Demo2-PostgresOutput
#   cd python/demo2-postgres-output
#   cd java/demo2-postgres-output
#   dapr run -f .
#   docker exec bindings-postgres psql -U dapr -d dapr -c "\dt"
#   docker exec bindings-postgres psql -U dapr -d dapr -c "SELECT * FROM warp_core_readings;"
#   docker rm -f bindings-postgres >/dev/null 2>&1 || true
#   docker run -d --name bindings-postgres -p 127.0.0.1:5432:5432 \
#   -e POSTGRES_USER=dapr -e POSTGRES_PASSWORD=dapr -e POSTGRES_DB=dapr \
#   -v /root/university-labs/bindings/sql:/docker-entrypoint-initdb.d:ro \
#   postgres:18.7
#   for _ in $(seq 1 60); do
#   docker exec bindings-postgres psql -h 127.0.0.1 -U dapr -d dapr -tAc 'SELECT 1 FROM comms_log' >/dev/null 2>&1 && break
#   sleep 1
#   done
