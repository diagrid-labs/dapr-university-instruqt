*** Settings ***
Documentation     Drift test for dapr-101 challenge 3 (State Management HTTP API).
Resource          ../../../tools/track-tester/resources/dapr.resource
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${SIDECAR_LOG}    ${TEMPDIR}/dapr-101-ch3-sidecar.log

*** Test Cases ***
State Management API Round Trip
    Start Background Process
    ...    dapr run --app-id myapp --dapr-http-port 3500    ${SIDECAR_LOG}    sidecar
    Wait Until Log Contains    ${SIDECAR_LOG}    You're up and running!    timeout=60s

    Run And Expect RC Zero
    ...    curl -X POST -H "Content-Type: application/json" -d '[{ "key": "name", "value": "Bruce Wayne"}]' http://localhost:3500/v1.0/state/statestore

    Assert Command Output Contains
    ...    curl http://localhost:3500/v1.0/state/statestore/name    Bruce Wayne

    Assert Redis Keys Contain    myapp||name

    Run And Expect RC Zero
    ...    curl -v -X DELETE -H "Content-Type: application/json" http://localhost:3500/v1.0/state/statestore/name

    ${r}=    Run And Expect RC Zero    docker exec dapr_redis redis-cli KEYS '*'
    Should Not Contain    ${r.stdout}    myapp||name

    Stop Process With SIGINT    sidecar
    Wait Until Log Contains    ${SIDECAR_LOG}    Exited Dapr successfully    timeout=15s

Statestore Component File Is Redis
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
