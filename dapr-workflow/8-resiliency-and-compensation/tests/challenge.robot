*** Settings ***
Documentation     Drift test for dapr-workflow challenge 8 (resiliency & compensation) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch8.log
${OUTPUT}     "dapr.workflow.output":"1"

*** Test Cases ***
DotNet Resiliency
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build ResiliencyAndCompensation    ${WF_BASE}/csharp/resiliency-and-compensation
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/resiliency-and-compensation    ${LOG}    http://localhost:5264/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5264/start/1 -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3564/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Resiliency
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/resiliency-and-compensation    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST --url http://localhost:8080/start/1
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    1

Python Resiliency
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/resiliency-and-compensation/resiliency_and_compensation
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/resiliency-and-compensation/resiliency_and_compensation
    Start Workflow App    bash -c 'source resiliency_and_compensation/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/resiliency-and-compensation    ${LOG}    http://localhost:5264/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5264/start/1 -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3564/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/resiliency-and-compensation
#   cd java/resiliency-and-compensation
#   cd python/resiliency-and-compensation/resiliency_and_compensation
#   source venv/bin/activate
#   cd ..
