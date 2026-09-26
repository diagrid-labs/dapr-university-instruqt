*** Settings ***
Documentation     Drift test for dapr-bindings challenge 2 (Save state with an output binding).
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_bindings.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${APP_DIR}    ${AI_AGENT_TRACKS_DIR}/bindings/venue-bookings
${LOG}        ${TEMPDIR}/dapr-bindings-ch2.log

*** Test Cases ***
Python Save A Booking With Exec Operation
    [Tags]    python
    Start Background Process
    ...    uv run dapr run --app-id venue-bookings --resources-path ./resources -- python app.py
    ...    ${LOG}    app    cwd=${APP_DIR}
    Wait Until Log Contains    ${LOG}    Uvicorn running on http://0.0.0.0:8006
    Assert Command Output Contains
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "event_date": "2026-03-15"}'
    ...    "status":"saved"
    Assert Command Output Contains
    ...    docker exec dapr_postgres psql -U postgres -d venuedb -c "SELECT * FROM bookings;"
    ...    Grand Ballroom
    Stop Process With SIGINT    app
