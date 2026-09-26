*** Settings ***
Documentation     Drift test for dapr-bindings challenge 3 (Query state with the same binding).
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_bindings.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${APP_DIR}    ${AI_AGENT_TRACKS_DIR}/bindings/venue-bookings
${LOG}        ${TEMPDIR}/dapr-bindings-ch3.log

*** Test Cases ***
Python Query Bookings With The Same Binding
    [Tags]    python
    Start Background Process
    ...    uv run dapr run --app-id venue-bookings --resources-path ./resources -- python app.py
    ...    ${LOG}    app    cwd=${APP_DIR}
    Wait Until Log Contains    ${LOG}    Uvicorn running on http://0.0.0.0:8006
    Assert Command Output Contains    curl http://localhost:8006/bookings    bookings
    Assert Command Output Contains
    ...    curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "event_date": "2026-04-02"}'
    ...    "status":"saved"
    Assert Command Output Contains    curl http://localhost:8006/bookings    Rooftop Terrace
    Stop Process With SIGINT    app
