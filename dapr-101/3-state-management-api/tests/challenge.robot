*** Settings ***
Name              Ch3 State Management
Documentation     Drift test for dapr-101 challenge 3 (State Management HTTP API).
# Imports the shared custom keywords (see tools/track-tester/resources/dapr.resource).
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_101.py
# Runs after all tests to clean up any leftover processes, even on failure.
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
# `${TEMPDIR}` is a built-in Robot Framework variable (the OS temp dir). We build a
# path for the Dapr sidecar's log file so later steps can wait for lines to appear in it.
${SIDECAR_LOG}    ${TEMPDIR}/dapr-101-ch3-sidecar.log

*** Test Cases ***
State Management API Round Trip
    # Launch the sidecar-only run template in the background (non-blocking), from the demo
    # folder the page cd's into. Args: command, logfile, alias ("sidecar"), working directory.
    # Remove log files from earlier runs, so the log check below only sees this run.
    Remove Directory    ${DAPR101_BASE}/${STATE_DEMO}/.dapr    recursive=True
    Start Background Process
    ...    dapr run -f .    ${SIDECAR_LOG}    sidecar    ${DAPR101_BASE}/${STATE_DEMO}
    # The run template prints this when the sidecar has started.
    Wait Until Log Contains    ${SIDECAR_LOG}    Started Dapr with app id "myapp". HTTP Port: 3500    timeout=60s
    # The page tells the learner the sidecar log goes to a file (for the Dev Dashboard Logs page).
    Wait Until Log Contains    ${SIDECAR_LOG}    Writing log files to directory    timeout=15s
    # Wait until the sidecar answers on port 3500 before calling the State API.
    Wait Until Command Output Contains
    ...    curl -s -o /dev/null -w "\%{http_code}" http://localhost:3500/v1.0/healthz    204
    # The Dev Dashboard Logs page reads the sidecar log file; check the line the page has the
    # learner search for is in it.
    ${logs}=    Run And Expect RC Zero    cat ${DAPR101_BASE}/${STATE_DEMO}/.dapr/logs/myapp_daprd_*.log
    Should Contain    ${logs.stdout}    Component loaded: statestore (state.redis/v1)

    # POST a key/value into the state store via the Dapr HTTP API; fail if the exit code isn't 0.
    Run And Expect RC Zero
    ...    curl -X POST -H "Content-Type: application/json" -d '[{ "key": "name", "value": "Bruce Wayne"}]' http://localhost:3500/v1.0/state/statestore

    # GET the value back and assert the response body contains what we stored.
    Assert Command Output Contains
    ...    curl http://localhost:3500/v1.0/state/statestore/name    Bruce Wayne

    # The page has the learner check the record on the Dev Dashboard State page (key `name`,
    # app prefix `myapp`). The dashboard is not testable here, so this redis-cli assertion on the
    # Redis container stands in for it: it proves the `myapp||name` key the page describes exists.
    Assert Redis Keys Contain    myapp||name

    # DELETE the key via the Dapr API.
    Run And Expect RC Zero
    ...    curl -v -X DELETE -H "Content-Type: application/json" http://localhost:3500/v1.0/state/statestore/name

    # Stand-in for the page's second State page step: confirm the key is really gone.
    # `Should Not Contain` is the negative assertion.
    ${r}=    Run And Expect RC Zero    docker exec dapr_redis redis-cli KEYS '*'
    Should Not Contain    ${r.stdout}    myapp||name

    # Send SIGINT (like Ctrl+C) to the "sidecar" process and wait for its clean-exit log line.
    Stop Process With SIGINT    sidecar
    # Check that the sidecar is really gone: port 3500 no longer answers (curl rc 7). Not the
    # page's stop message: on Linux `dapr run -f .` moves itself into its own process group, so
    # the group SIGINT doesn't reach the CLI and the keyword's tree-kill fallback stops it
    # without that message. A learner's Ctrl+C in a terminal does reach it.
    Wait Until Keyword Succeeds    15s    1s    Sidecar Port Is Closed

Statestore Component File Is Redis
    # `%{HOME}` reads the HOME environment variable (%{...} = env var, ${...} = RF variable).
    ${r}=    Run And Expect RC Zero    cat %{HOME}/.dapr/components/statestore.yaml
    Should Contain    ${r.stdout}    type: state.redis
    Should Contain    ${r.stdout}    name: statestore

*** Keywords ***
Sidecar Port Is Closed
    ${r}=    Run Process    curl -s -o /dev/null http://localhost:3500/v1.0/healthz    shell=True
    Should Not Be Equal As Integers    ${r.rc}    0

# doc-sync coverage:
#   cd /root/ai-agent-tracks-instruqt/dapr-101/state-management
#   (the suite runs `dapr run -f .` with cwd=${DAPR101_BASE}/${STATE_DEMO}, the same folder)
#   cat ~/.dapr/components/statestore.yaml
#   (asserted above via `cat %{HOME}/.dapr/components/statestore.yaml`, the
#   Robot Framework/shell-portable equivalent of the assignment's `~`)
