*** Settings ***
Documentation     Drift test for dapr-bindings challenge 2 (Save state with an output binding) across languages.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_bindings.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${APP_DIR}    ${AI_AGENT_TRACKS_DIR}/bindings/venue-bookings
${LOG}        ${TEMPDIR}/dapr-bindings-ch2.log

*** Test Cases ***
Python Save A Booking With Exec Operation
    [Tags]    python
    Save A Booking
    ...    uv run dapr run --app-id venue-bookings --resources-path ./resources -- python app.py
    ...    ${APP_DIR}/python
    ...    Uvicorn running on http://0.0.0.0:8006
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "event_date": "2026-03-15"}'
    ...    "status":"saved","rows_affected":"1"

DotNet Save A Booking With Exec Operation
    [Tags]    dotnet
    Save A Booking
    ...    dapr run --app-id venue-bookings --resources-path ./resources -- dotnet run
    ...    ${APP_DIR}/dotnet
    ...    Now listening on: http://0.0.0.0:8006
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "eventDate": "2026-03-15"}'
    ...    "status":"saved","rows_affected":"1"

Java Save A Booking With Exec Operation
    [Tags]    java
    Save A Booking
    ...    dapr run --app-id venue-bookings --resources-path ./resources -- mvn spring-boot:run
    ...    ${APP_DIR}/java
    ...    Tomcat started on port 8006
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "eventDate": "2026-03-15"}'
    ...    {"status":"saved"}

*** Keywords ***
Save A Booking
    [Arguments]    ${run_command}    ${cwd}    ${ready_marker}    ${curl_command}    ${expected_response}
    Start Background Process    ${run_command}    ${LOG}    app    cwd=${cwd}
    Wait Until Log Contains    ${LOG}    ${ready_marker}    timeout=240s
    Assert Command Output Contains    ${curl_command}    ${expected_response}
    Assert Command Output Contains
    ...    docker exec dapr_postgres psql -U postgres -d venuedb -c "SELECT * FROM bookings;"
    ...    Grand Ballroom
    Stop Process With SIGINT    app

# doc-sync coverage (expressed via the cwd argument above):
#   cd python
#   cd dotnet
#   cd java
