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
    ...    uv run dapr run --app-id venue-bookings --resources-path ../resources -- python app.py
    ...    ${APP_DIR}/python
    ...    Uvicorn running on http://0.0.0.0:8006
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "event_date": "2026-04-02"}'
    ...    event_date

DotNet Query Bookings With The Same Binding
    [Tags]    dotnet
    Query Bookings
    ...    dapr run --app-id venue-bookings --resources-path ../resources -- dotnet run --project src/VenueBookings
    ...    ${APP_DIR}/dotnet
    ...    Now listening on: http://0.0.0.0:8006
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "event_date": "2026-04-02"}'
    ...    event_date

Java Query Bookings With The Same Binding
    [Tags]    java
    Query Bookings
    ...    dapr run --app-id venue-bookings --resources-path ../resources -- bash ./mvnw spring-boot:run
    ...    ${APP_DIR}/java
    ...    Tomcat started on port 8006
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "eventDate": "2026-04-02"}'
    ...    eventDate

*** Keywords ***
Query Bookings
    [Arguments]    ${run_command}    ${cwd}    ${ready_marker}    ${save_command}    ${date_key}
    [Teardown]    Stop Process With SIGINT    app
    Start Background Process    ${run_command}    ${LOG}    app    cwd=${cwd}
    Wait Until Log Contains    ${LOG}    ${ready_marker}    timeout=240s
    Assert Booking Is Returned    Grand Ballroom    2026-03-15    ${date_key}
    Run And Expect RC Zero    ${save_command}
    Assert Booking Is Returned    Rooftop Terrace    2026-04-02    ${date_key}

Assert Booking Is Returned
    [Arguments]    ${venue}    ${event_date}    ${date_key}
    ${result}=    Run And Expect RC Zero    curl --fail-with-body http://localhost:8006/bookings
    ${body}=    Evaluate    json.loads($result.stdout)    modules=json
    ${matches}=    Evaluate    [row for row in $body["bookings"] if row.get("venue") == $venue and row.get($date_key) == $event_date]
    Should Not Be Empty    ${matches}    No booking matched the expected venue, date and JSON field name.

# doc-sync coverage (expressed via the cwd argument above):
#   cd python
#   cd dotnet
#   cd java
# GET is executed above with --fail-with-body to make HTTP errors fail the test:
#   curl http://localhost:8006/bookings
