*** Settings ***
Documentation     Drift test for dapr-workflow challenge 2 (fundamentals) across languages.
Resource          ../../../tools/track-tester/resources/workflow.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow.py
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${LOG}        ${TEMPDIR}/dapr-workflow-ch2.log
${OUTPUT}     \\"One Two Three\\"

*** Test Cases ***
DotNet Fundamentals
    [Tags]    dotnet
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    dotnet build Basic    ${WF_BASE}/csharp/fundamentals
    Start Workflow App    dapr run -f .    ${WF_BASE}/csharp/fundamentals    ${LOG}    http://localhost:5254/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5254/start/One -i | grep -i "^location:" | sed 's/^location: *//i' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3554/v1.0/workflows/dapr/${id}    ${OUTPUT}

Java Fundamentals
    [Tags]    java
    [Teardown]    Stop Process With SIGINT    app
    Start Workflow App    mvn spring-boot:test-run    ${WF_BASE}/java/fundamentals    ${LOG}    http://localhost:8080/    timeout=300s
    Run And Expect RC Zero    curl -i --request POST "http://localhost:8080/start?input=One"
    Wait Until Command Output Contains    curl -s http://localhost:8080/output    One Two Three

Python Fundamentals
    [Tags]    python
    [Teardown]    Stop Process With SIGINT    app
    Run And Expect RC Zero    python3 -m venv venv    ${WF_BASE}/python/fundamentals/basic
    Run And Expect RC Zero    bash -c 'source venv/bin/activate && pip3 install -r requirements.txt'    ${WF_BASE}/python/fundamentals/basic
    Start Workflow App    bash -c 'source basic/venv/bin/activate && dapr run -f .'    ${WF_BASE}/python/fundamentals    ${LOG}    http://localhost:5254/
    ${id}=    Capture Command Output
    ...    curl -s --request POST --url http://localhost:5254/start/One -i | grep -o '"instance_id":"[^"]*"' | sed 's/"instance_id":"//;s/"//g' | tr -d '\\r\\n'
    Wait Until Workflow Completed    http://localhost:3554/v1.0/workflows/dapr/${id}    ${OUTPUT}

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/fundamentals
#   cd java/fundamentals
#   cd python/fundamentals/basic
#   source venv/bin/activate
#   cd ..
#   echo $INSTANCEID
#   keys *basic||dapr.internal.default.basic.workflow*
