*** Settings ***
Resource    ../dapr.resource
Variables   ../../variables/dapr_101.py

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
