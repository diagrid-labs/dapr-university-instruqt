*** Settings ***
Library    Process
Library    OperatingSystem
Library    Collections

*** Keywords ***
Start Background Process
    [Arguments]    ${command}    ${logfile}    ${alias}    ${cwd}=${EMPTY}
    Create File    ${logfile}    ${EMPTY}
    ${handle}=    Start Process    ${command}    shell=True    alias=${alias}
    ...    cwd=${cwd}    stdout=${logfile}    stderr=STDOUT
    RETURN    ${handle}

Wait Until Log Contains
    [Arguments]    ${logfile}    ${text}    ${timeout}=60s
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    File Should Contain    ${logfile}    ${text}

File Should Contain
    [Arguments]    ${logfile}    ${text}
    ${content}=    Get File    ${logfile}
    Should Contain    ${content}    ${text}

Stop Process With SIGINT
    [Arguments]    ${alias}    ${timeout}=15s
    Send Signal To Process    SIGINT    ${alias}
    ${result}=    Wait For Process    ${alias}    timeout=${timeout}    on_timeout=kill
    RETURN    ${result}

Run And Expect RC Zero
    [Arguments]    ${command}    ${cwd}=${EMPTY}
    ${result}=    Run Process    ${command}    shell=True    cwd=${cwd}
    ...    stdout=PIPE    stderr=STDOUT    timeout=300s
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=Command failed (rc=${result.rc}): ${command}\n${result.stdout}
    RETURN    ${result}

Assert Command Output Contains
    [Arguments]    ${command}    ${text}    ${cwd}=${EMPTY}
    ${result}=    Run And Expect RC Zero    ${command}    ${cwd}
    Should Contain    ${result.stdout}    ${text}
    RETURN    ${result}

Run Multi-App And Assert Markers
    [Arguments]    ${run_command}    ${cwd}    ${logfile}    ${markers}    ${timeout}=180s
    Start Background Process    ${run_command}    ${logfile}    apps    cwd=${cwd}
    FOR    ${marker}    IN    @{markers}
        Wait Until Log Contains    ${logfile}    ${marker}    ${timeout}
    END
    Stop Process With SIGINT    apps

Assert Redis Keys Contain
    [Arguments]    ${key}
    Assert Command Output Contains    docker exec dapr_redis redis-cli KEYS *    ${key}
