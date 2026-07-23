*** Settings ***
Name              Ch9 Combined Patterns
Documentation     Drift test for dapr-workflow challenge 9 (combined patterns) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}         ${TEMPDIR}/dapr-workflow-ch9.log
${LOG2}        ${TEMPDIR}/dapr-workflow-ch9-shipping.log
${ORDER_ID}    b0d38481-5547-411e-ae7b-255761cce17a
${OUTPUT}      processed successfully

*** Test Cases ***
DotNet Combined Patterns
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build ShippingApp    ${WF_BASE}/csharp/combined-patterns
    Run And Expect RC Zero    dotnet build WorkflowApp    ${WF_BASE}/csharp/combined-patterns
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/combined-patterns    ${LOG}    http://localhost:5260/
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5260/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","orderItem" : {"productId": "RBD001","productName": "Rubber Duck","quantity": 10,"totalPrice": 15.00},"customerInfo" : {"id" : "Customer1","country" : "The Netherlands"}}'
    Wait Until Workflow Completed    http://localhost:3560/v1.0/workflows/dapr/${ORDER_ID}    ${OUTPUT}

Java Combined Patterns
    [Tags]    java
    [Setup]    Enable Testcontainers Reuse
    [Teardown]    Run Keywords    Stop Process With SIGINT    app    AND    Stop Process With SIGINT    shipping
    Start Workflow App    mvn clean -Dspring-boot.run.arguments="--reuse=true" spring-boot:test-run    ${WF_BASE}/java/combined-patterns/workflow-app    ${LOG}    http://localhost:8080/    app    timeout=300s
    Start Background Process    mvn clean -Dspring-boot.run.arguments="--reuse=true" spring-boot:test-run    ${LOG2}    shipping    cwd=${WF_BASE}/java/combined-patterns/shipping-app
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:8080/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","orderItem" : {"productId": "RBD001","productName": "Rubber Duck","quantity": 10,"totalPrice": 15.00},"customerInfo" : {"id" : "Customer1","country" : "The Netherlands"}}'
    Wait Until Command Output Contains    curl -s "http://localhost:8080/output?instanceId=${ORDER_ID}"    processed successfully    180s

Python Combined Patterns
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/combined-patterns
    Run And Expect RC Zero    bash -c 'source ../venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/combined-patterns/workflow_app
    Run And Expect RC Zero    bash -c 'source ../venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/combined-patterns/shipping_app
    Start Workflow App    bash -c 'source venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/combined-patterns    ${LOG}    http://localhost:5260/
    Run And Expect RC Zero
    ...    curl -i --request POST --url http://localhost:5260/start --header 'content-type: application/json' --data '{"id": "${ORDER_ID}","order_item" : {"product_id": "RBD001","product_name": "Rubber Duck","quantity": 10,"total_price": 15.00},"customer_info" : {"id" : "Customer1","country" : "The Netherlands"}}'
    Wait Until Workflow Completed    http://localhost:3560/v1.0/workflows/dapr/${ORDER_ID}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/combined-patterns
#   cd java/combined-patterns/workflow-app
#   cd java/combined-patterns/shipping-app
#   cd python/combined-patterns
#   source venv/bin/activate
#   cd workflow_app
#   cd ..
#   cd shipping_app
