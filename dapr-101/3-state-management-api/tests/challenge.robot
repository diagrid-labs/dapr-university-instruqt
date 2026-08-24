*** Settings ***
Documentation     Drift test for dapr-101 challenge 3 (State Management HTTP API).
# Imports the shared custom keywords (see tools/track-tester/resources/dapr.resource).
Resource          ../../../tools/track-tester/resources/dapr.resource
# Runs after all tests to clean up any leftover processes, even on failure.
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
# `${TEMPDIR}` is a built-in Robot Framework variable (the OS temp dir). We build a
# path for the Dapr sidecar's log file so later steps can wait for lines to appear in it.
${SIDECAR_LOG}    ${TEMPDIR}/dapr-101-ch3-sidecar.log

*** Test Cases ***
State Management API Round Trip
    # Launch the Dapr sidecar in the background (non-blocking). Args: command,
    # logfile to capture stdout/stderr, and an alias ("sidecar") to reference it later.
    # `...` continues the call onto the next line — the args live on the wrapped line.
    Start Background Process
    ...    dapr run --app-id myapp --dapr-http-port 3500    ${SIDECAR_LOG}    sidecar
    # Poll the log until the ready message appears, giving up after 60s. `timeout=60s`
    # is a named argument (name=value), not a positional one.
    Wait Until Log Contains    ${SIDECAR_LOG}    You're up and running!    timeout=60s

    # POST a key/value into the state store via the Dapr HTTP API; fail if the exit code isn't 0.
    Run And Expect RC Zero
    ...    curl -X POST -H "Content-Type: application/json" -d '[{ "key": "name", "value": "Bruce Wayne"}]' http://localhost:3500/v1.0/state/statestore

    # GET the value back and assert the response body contains what we stored.
    Assert Command Output Contains
    ...    curl http://localhost:3500/v1.0/state/statestore/name    Bruce Wayne

    # Custom keyword: run `redis-cli KEYS *` inside the Redis container and assert the key exists.
    Assert Redis Keys Contain    myapp||name

    # DELETE the key via the Dapr API.
    Run And Expect RC Zero
    ...    curl -v -X DELETE -H "Content-Type: application/json" http://localhost:3500/v1.0/state/statestore/name

    # Confirm the key is really gone. `Should Not Contain` is the negative assertion.
    ${r}=    Run And Expect RC Zero    docker exec dapr_redis redis-cli KEYS '*'
    Should Not Contain    ${r.stdout}    myapp||name

    # Send SIGINT (like Ctrl+C) to the "sidecar" process and wait for its clean-exit log line.
    Stop Process With SIGINT    sidecar
    Wait Until Log Contains    ${SIDECAR_LOG}    Exited Dapr successfully    timeout=15s

Statestore Component File Is Redis
    # `%{HOME}` reads the HOME environment variable (%{...} = env var, ${...} = RF variable).
    ${r}=    Run And Expect RC Zero    cat %{HOME}/.dapr/components/statestore.yaml
    Should Contain    ${r.stdout}    type: state.redis
    Should Contain    ${r.stdout}    name: statestore

# doc-sync coverage:
#   keys *
#   (run twice in the assignment's Redis terminal; asserted above via
#   `docker exec dapr_redis redis-cli KEYS *` through Assert Redis Keys Contain)
#   cat ~/.dapr/components/statestore.yaml
#   (asserted above via `cat %{HOME}/.dapr/components/statestore.yaml`, the
#   Robot Framework/shell-portable equivalent of the assignment's `~`)
