*** Settings ***
Name              Ch6 External Events
Documentation     Drift test for dapr-workflow challenge 6 (external events) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch6.log
${ORDER_ID}   b7dd836b-e913-4446-9912-d400befebec5
${OUTPUT}     has been approved

*** Test Cases ***
DotNet External Events
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build ExternalEvents    ${WF_BASE}/csharp/external-system-interaction
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/external-system-interaction    ${LOG}    http://localhost:5258/
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5258/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","description": "Rubber ducks","quantity": 100,"totalPrice": 500}'
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:3558/v1.0/workflows/dapr/${ORDER_ID}/raiseEvent/approval-event --header 'content-type: application/json' --data '{"OrderId": "${ORDER_ID}","IsApproved": true}'
    Wait Until Workflow Completed    http://localhost:3558/v1.0/workflows/dapr/${ORDER_ID}    ${OUTPUT}

Java External Events
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/external-system-interactions    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:8080/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","description": "Rubber ducks","quantity": 100,"totalPrice": 500}'
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:8080/event --header 'content-type: application/json' --data '{"orderId": "${ORDER_ID}","isApproved": true}'
    Wait Until Command Output Contains    curl -s http://localhost:8080/status    COMPLETED
    Assert Command Output Contains    curl -s http://localhost:8080/status    ${OUTPUT}

Python External Events
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/external-system-interaction/external_events
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/external-system-interaction/external_events
    Start Workflow App    bash -c 'source external_events/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/external-system-interaction    ${LOG}    http://localhost:5258/
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5258/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","description": "Rubber ducks","quantity": 100,"total_price": 500}'
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:3558/v1.0/workflows/dapr/${ORDER_ID}/raiseEvent/approval-event --header 'content-type: application/json' --data '{"order_id": "${ORDER_ID}","is_approved": true}'
    Wait Until Workflow Completed    http://localhost:3558/v1.0/workflows/dapr/${ORDER_ID}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/external-system-interaction
#   cd java/external-system-interactions
#   cd python/external-system-interaction/external_events
#   source venv/bin/activate
#   cd ..
