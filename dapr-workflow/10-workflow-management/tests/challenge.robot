*** Settings ***
Name              Ch10 Workflow Management
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
    # given app base URL and instance id. The never-ending workflow never completes,
    # and the app's /status endpoint serializes runtime_status differently per language
    # (a numeric enum for .NET/Python, a string for Java) - the assignment's own examples
    # confirm this and it never re-checks status after the transitions. So we assert HTTP
    # success (2xx) on each management operation - the real endpoint/port/verb drift
    # signal - rather than matching a brittle, language-specific status string.
    [Arguments]    ${base}    ${id}
    Wait Until Keyword Succeeds    30s    2s    Assert HTTP Success    GET    ${base}/status/${id}
    Assert HTTP Success    POST      ${base}/suspend/${id}
    Assert HTTP Success    POST      ${base}/resume/${id}
    Assert HTTP Success    POST      ${base}/terminate/${id}
    Assert HTTP Success    DELETE    ${base}/purge/${id}

Assert HTTP Success
    # curl exits 0 for any HTTP response (no -f), so a 4xx/5xx would slip past an rc check.
    # Discard the body, print only the numeric status code, and assert it is 2xx.
    [Arguments]    ${method}    ${url}
    ${code}=    Capture Command Output    curl -s -o /dev/null -w "\%{http_code}" --request ${method} --url ${url}
    Should Match Regexp    ${code}    ^2\\d\\d$

# doc-sync coverage (expressed via cwd / bash -c above):
#   cd csharp/workflow-management
#   cd java/workflow-management
#   cd python/workflow-management/workflow_management
#   source venv/bin/activate
#   cd ..
