*** Settings ***
Resource    ../dapr.resource
Variables   ../../variables/dapr_101.py
Resource    ../workflow.resource
Resource    ../aspire.resource

*** Test Cases ***
Keywords Resolve
    [Documentation]    Dry-run only: verifies every shared keyword and variable resolves.
    Start Background Process    echo hi    /tmp/x.log    smoke
    Wait Until Log Contains    /tmp/x.log    hi
    Stop Process With SIGINT    smoke
    Run And Expect RC Zero    true
    Assert Command Output Contains    echo hi    hi
    Run Multi-App And Assert Markers    echo hi    ${EMPTY}    /tmp/y.log    ${SVC_MARKERS}
    Assert Redis Keys Contain    somekey

Workflow Keywords Resolve
    [Documentation]    Dry-run only: verifies the workflow.resource keywords resolve.
    Wait Until App Responds    http://localhost:1/    1s
    Start Workflow App    echo hi    ${EMPTY}    /tmp/wf.log    http://localhost:1/    wfapp    1s
    Capture Command Output    echo hi
    Wait Until Command Output Contains    echo hi    hi
    Wait Until Workflow Completed    http://localhost:1/    someoutput

Aspire Keywords Resolve
    [Documentation]    Dry-run only: verifies the aspire.resource keywords resolve.
    Start Aspire Run    aspire run    ${EMPTY}    /tmp/aspire.log    aspiresmoke
    Wait Until Loopback Host Answers    http://localhost:1/    localhost:1    1s
    Aspire Resources    /tmp/apphost.cs    hidden=${True}
    Aspire Resource Pid    /tmp/apphost.cs    engineering
    Capture Aspire Logs And Stop App    /tmp/apphost.cs    aspiresmoke    ports=${{ [1] }}
