*** Settings ***
Documentation     Drift test for dapr-workflow challenge 10 (workflow management) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch10.log

*** Test Cases ***
DotNet Workflow Management
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build WorkflowManagement    ${WF_BASE}/csharp/workflow-management
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/workflow-management    ${LOG}    http://localhost:5262/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5262/start/0 -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Manage Workflow Lifecycle    http://localhost:5262    ${id}

Java Workflow Management
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/workflow-management    ${LOG}    http://localhost:8080/    timeout=300s
    ${id}=    Capture Command Output    curl -s --request POST --url http://localhost:8080/start/0
    Manage Workflow Lifecycle    http://localhost:8080    ${id}

Python Workflow Management
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/workflow-management/workflow_management
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/workflow-management/workflow_management
    Start Workflow App    bash -c 'source workflow_management/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/workflow-management    ${LOG}    http://localhost:5262/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5262/start/0 -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Manage Workflow Lifecycle    http://localhost:5262    ${id}

*** Keywords ***
Manage Workflow Lifecycle
    # Exercises the suspend/resume/terminate/purge management endpoints against the
    # given app base URL and instance id, asserting the status transitions.
    [Arguments]    ${base}    ${id}
    Wait Until Command Output Contains    curl -s ${base}/status/${id}    RUNNING
    Run And Expect RC Zero    curl -i --request POST --url ${base}/suspend/${id}
    Wait Until Command Output Contains    curl -s ${base}/status/${id}    SUSPENDED
    Run And Expect RC Zero    curl -i --request POST --url ${base}/resume/${id}
    Wait Until Command Output Contains    curl -s ${base}/status/${id}    RUNNING
    Run And Expect RC Zero    curl -i --request POST --url ${base}/terminate/${id}
    Wait Until Command Output Contains    curl -s ${base}/status/${id}    TERMINATED
    Run And Expect RC Zero    curl -i --request DELETE --url ${base}/purge/${id}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/workflow-management
#   cd java/workflow-management
#   cd python/workflow-management/workflow_management
#   source venv/bin/activate
#   cd ..
