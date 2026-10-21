# Reusable keywords for the dapr-workflow suites. Imports the generic Dapr
# process/assertion keywords from dapr.resource and adds workflow-specific ones
# (workflow-status polling, app launch). Generic readiness
# and output helpers live in dapr.resource.

*** Settings ***
Resource    dapr.resource

*** Keywords ***
Start Workflow App
    # Launch the app in the background (non-blocking) and wait until it is ready.
    [Arguments]    ${command}    ${cwd}    ${logfile}    ${probe_url}    ${alias}=app    ${timeout}=120s
    Start Background Process    ${command}    ${logfile}    ${alias}    cwd=${cwd}
    Wait Until App Responds    ${probe_url}    ${timeout}

Enable Testcontainers Reuse
    # Testcontainers only reuses a running container across processes when the
    # user-level flag testcontainers.reuse.enable=true is present in
    # ~/.testcontainers.properties. Without it, `--reuse=true` is ignored and each
    # Spring Boot app spins up its own container, so the two Java apps in the
    # combined-patterns challenge can't share one (and the run fails/times out).
    # Ensure the flag idempotently: create the file if missing, and append the line
    # only when it isn't already there so we don't clobber other properties.
    Run And Expect RC Zero
    ...    bash -c 'touch ~/.testcontainers.properties && grep -qxF "testcontainers.reuse.enable=true" ~/.testcontainers.properties || echo "testcontainers.reuse.enable=true" >> ~/.testcontainers.properties'

Wait Until Workflow Completed
    # Poll the Dapr workflow status endpoint until the instance reports COMPLETED,
    # then (optionally) assert the workflow output contains an expected substring.
    [Arguments]    ${status_url}    ${expected_output}=${EMPTY}    ${timeout}=90s
    Wait Until Command Output Contains    curl -s ${status_url}    "runtimeStatus":"COMPLETED"    ${timeout}
    IF    '${expected_output}' != '${EMPTY}'
        Assert Command Output Contains    curl -s ${status_url}    ${expected_output}
    END
