*** Settings ***
Name              Ch3 Task Chaining
Documentation     Drift test for dapr-workflow challenge 3 (task chaining) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch3.log
# Dapr double-JSON-encodes string workflow outputs, so the status response contains
# escaped inner quotes (\"This is task chaining\"). Robot's \\ collapses to one
# backslash at runtime, producing the escaped substring the response actually holds.
${OUTPUT}     \\"This is task chaining\\"

*** Test Cases ***
DotNet Task Chaining
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build TaskChaining    ${WF_BASE}/csharp/task-chaining
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/task-chaining    ${LOG}    http://localhost:5255/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5255/start -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3555/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Task Chaining
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/task-chaining    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST http://localhost:8080/start
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    This is task chaining

Python Task Chaining
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/task-chaining/task_chaining
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/task-chaining/task_chaining
    Start Workflow App    bash -c 'source task_chaining/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/task-chaining    ${LOG}    http://localhost:5255/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5255/start -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3555/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/task-chaining
#   cd java/task-chaining
#   cd python/task-chaining/task_chaining
#   source venv/bin/activate
#   cd ..
