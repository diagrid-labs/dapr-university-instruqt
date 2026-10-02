*** Settings ***
Documentation     Drift test for dapr-bindings challenge 3 (Query state with the same binding) across languages.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_bindings.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${APP_DIR}    ${AI_AGENT_TRACKS_DIR}/bindings/venue-bookings
${LOG}        ${TEMPDIR}/dapr-bindings-ch3.log

*** Test Cases ***
Python Query Bookings With The Same Binding
    [Tags]    python
    Query Bookings
    ...    uv run dapr run --app-id venue-bookings --resources-path ./resources -- python app.py
    ...    ${APP_DIR}/python
    ...    Uvicorn running on http://0.0.0.0:8006
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "event_date": "2026-04-02"}'

DotNet Query Bookings With The Same Binding
    [Tags]    dotnet
    Query Bookings
    ...    dapr run --app-id venue-bookings --resources-path ./resources -- dotnet run
    ...    ${APP_DIR}/dotnet
    ...    Now listening on: http://0.0.0.0:8006
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "eventDate": "2026-04-02"}'

Java Query Bookings With The Same Binding
    [Tags]    java
    Query Bookings
    ...    dapr run --app-id venue-bookings --resources-path ./resources -- mvn spring-boot:run
    ...    ${APP_DIR}/java
    ...    Tomcat started on port 8006
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "eventDate": "2026-04-02"}'

*** Keywords ***
Query Bookings
    [Arguments]    ${run_command}    ${cwd}    ${ready_marker}    ${save_command}
    Start Background Process    ${run_command}    ${LOG}    app    cwd=${cwd}
    Wait Until Log Contains    ${LOG}    ${ready_marker}    timeout=240s
    # The row saved in challenge 2 comes back, with the date as a timestamp string.
    Assert Command Output Contains    curl http://localhost:8006/bookings    Grand Ballroom
    Assert Command Output Contains    curl http://localhost:8006/bookings    2026-03-15T00:00:00Z
    Run And Expect RC Zero    ${save_command}
    Assert Command Output Contains    curl http://localhost:8006/bookings    Rooftop Terrace
    Stop Process With SIGINT    app

# doc-sync coverage (expressed via the cwd argument above):
#   cd python
#   cd dotnet
#   cd java
