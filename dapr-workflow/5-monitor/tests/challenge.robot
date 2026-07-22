*** Settings ***
Name              Ch5 Monitor
Documentation     Drift test for dapr-workflow challenge 5 (monitor pattern) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch5.log
${OUTPUT}     Status is healthy after

*** Test Cases ***
DotNet Monitor
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build Monitor    ${WF_BASE}/csharp/monitor-pattern
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/monitor-pattern    ${LOG}    http://localhost:5257/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5257/start/0 -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Log Contains    ${LOG}    CheckStatus: Received input:    120s
    Wait Until Workflow Completed    http://localhost:3557/v1.0/workflows/dapr/${id}    ${OUTPUT}    timeout=180s

Java Monitor
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/monitor-pattern    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST http://localhost:8080/start/0
    Wait Until Log Contains    ${LOG}    Received input:    120s
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    Status is healthy after    180s

Python Monitor
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/monitor-pattern/monitor
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/monitor-pattern/monitor
    Start Workflow App    bash -c 'source monitor/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/monitor-pattern    ${LOG}    http://localhost:5257/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5257/start/0 -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Log Contains    ${LOG}    check_status: Received input:    120s
    Wait Until Workflow Completed    http://localhost:3557/v1.0/workflows/dapr/${id}    ${OUTPUT}    timeout=180s

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/monitor-pattern
#   cd java/monitor-pattern
#   cd python/monitor-pattern/monitor
#   source venv/bin/activate
#   cd ..
