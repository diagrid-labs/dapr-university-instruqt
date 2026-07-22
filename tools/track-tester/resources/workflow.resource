# Reusable keywords for the dapr-workflow suites. Imports the generic Dapr
# process/assertion keywords from dapr.resource and adds workflow-specific ones
# (readiness probing, instance-id capture, workflow-status polling).

*** Settings ***
Resource    dapr.resource
# String ships with Robot Framework; used here for Strip String.
Library     String

*** Keywords ***
Wait Until App Responds
    # Readiness probe: curl the app's port until the connection succeeds. A running
    # HTTP server returns *some* response (even 404) => curl exits 0; a refused
    # connection => curl exits 7. This is language-agnostic (works for the .NET,
    # Python and Java apps) and avoids depending on exact framework log lines.
    [Arguments]    ${probe_url}    ${timeout}=120s
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Run And Expect RC Zero    curl -s -o /dev/null ${probe_url}

Start Workflow App
    # Launch the app in the background (non-blocking) and wait until it is ready.
    [Arguments]    ${command}    ${cwd}    ${logfile}    ${probe_url}    ${alias}=app    ${timeout}=120s
    Start Background Process    ${command}    ${logfile}    ${alias}    cwd=${cwd}
    Wait Until App Responds    ${probe_url}    ${timeout}

Capture Command Output
    # Run a command to completion (rc 0 required) and return its stdout, stripped
    # of surrounding whitespace/newlines. Used to capture workflow instance IDs
    # from the assignment's curl+grep+sed pipelines.
    [Arguments]    ${command}    ${cwd}=${EMPTY}
    ${r}=    Run And Expect RC Zero    ${command}    ${cwd}
    ${out}=    Strip String    ${r.stdout}
    RETURN    ${out}

Wait Until Command Output Contains
    # Poll: retry running ${command} until its output contains ${text}.
    [Arguments]    ${command}    ${text}    ${timeout}=90s
    Wait Until Keyword Succeeds    ${timeout}    3s
    ...    Assert Command Output Contains    ${command}    ${text}

Wait Until Workflow Completed
    # Poll the Dapr workflow status endpoint until the instance reports COMPLETED,
    # then (optionally) assert the workflow output contains an expected substring.
    [Arguments]    ${status_url}    ${expected_output}=${EMPTY}    ${timeout}=90s
    Wait Until Command Output Contains    curl -s ${status_url}    "runtimeStatus":"COMPLETED"    ${timeout}
    IF    '${expected_output}' != '${EMPTY}'
        Assert Command Output Contains    curl -s ${status_url}    ${expected_output}
    END
