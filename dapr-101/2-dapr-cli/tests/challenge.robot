*** Settings ***
Documentation     Drift test for dapr-101 challenge 2 (Dapr CLI). Assumes the Dapr CLI is
...               already installed and `dapr init` has run (done by ci/setup-dapr-101.sh).
Resource          ../../../tools/track-tester/resources/dapr.resource
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${DAPR_VERSION}    1.18.0

*** Test Cases ***
Dapr CLI Reports Help
    Assert Command Output Contains    dapr -h    Distributed Application Runtime

Dapr Version Matches Pinned Runtime
    ${r}=    Run And Expect RC Zero    dapr --version
    Should Contain    ${r.stdout}    CLI version: ${DAPR_VERSION}
    Should Contain    ${r.stdout}    Runtime version: ${DAPR_VERSION}

Dapr Init Containers Are Running
    ${r}=    Run And Expect RC Zero    docker ps --format {{.Names}}
    Should Contain    ${r.stdout}    dapr_placement
    Should Contain    ${r.stdout}    dapr_scheduler
    Should Contain    ${r.stdout}    dapr_redis
    Should Contain    ${r.stdout}    dapr_zipkin

# doc-sync coverage (performed by ci/setup-dapr-101.sh, asserted above):
#   wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
#   dapr init
