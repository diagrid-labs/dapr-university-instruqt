*** Settings ***
Name              Ch4 Fan-Out/Fan-In
Documentation     Drift test for dapr-workflow challenge 4 (fan-out/fan-in) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch4.log
# Escaped-quote form (see ch3 note): the status response holds \"is\". The bare "is"
# would also match the input echo, so the quotes make the output assertion specific.
${OUTPUT}     \\"is\\"
${DATA}       ["which","word","is","the","shortest"]

*** Test Cases ***
DotNet Fan Out Fan In
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build FanOutFanIn    ${WF_BASE}/csharp/fan-out-fan-in
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/fan-out-fan-in    ${LOG}    http://localhost:5256/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5256/start --header 'content-type: application/json' --data '${DATA}' -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3556/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Fan Out Fan In
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/fan-out-fan-in    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST --url http://localhost:8080/start --header 'content-type: application/json' --data '${DATA}'
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    is

Python Fan Out Fan In
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/fan-out-fan-in/fan_out_fan_in
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/fan-out-fan-in/fan_out_fan_in
    Start Workflow App    bash -c 'source fan_out_fan_in/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/fan-out-fan-in    ${LOG}    http://localhost:5256/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5256/start --header 'content-type: application/json' --data '${DATA}' -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3556/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/fan-out-fan-in
#   cd java/fan-out-fan-in
#   cd python/fan-out-fan-in/fan_out_fan_in
#   source venv/bin/activate
#   cd ..
