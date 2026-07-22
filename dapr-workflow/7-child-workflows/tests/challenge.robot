*** Settings ***
Name              Ch7 Child Workflows
Documentation     Drift test for dapr-workflow challenge 7 (child workflows) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch7.log
${OUTPUT}     Item 1 is processed as a child workflow.
${DATA}       ["Item 1","Item 2"]

*** Test Cases ***
DotNet Child Workflows
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build ChildWorkflows    ${WF_BASE}/csharp/child-workflows
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/child-workflows    ${LOG}    http://localhost:5259/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5259/start --header 'content-type: application/json' --data '${DATA}' -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3559/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Child Workflows
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/child-workflows    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST --url http://localhost:8080/start --header 'content-type: application/json' --data '${DATA}'
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    Item 1 is processed as a child workflow.

Python Child Workflows
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/child-workflows/child_workflows
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/child-workflows/child_workflows
    Start Workflow App    bash -c 'source child_workflows/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/child-workflows    ${LOG}    http://localhost:5259/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5259/start --header 'content-type: application/json' --data '${DATA}' -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3559/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/child-workflows
#   cd java/child-workflows
#   cd python/child-workflows/child_workflows
#   source venv/bin/activate
#   cd ..
