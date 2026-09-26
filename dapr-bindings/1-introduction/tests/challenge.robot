*** Settings ***
Documentation     Drift test for dapr-bindings challenge 1 (Introduction).
Resource          ../../../tools/track-tester/resources/dapr.resource

*** Test Cases ***
Verify Dapr And Postgres Are Ready
    [Tags]    python
    ${result}=    Run And Expect RC Zero    dapr -v
    Should Contain    ${result.stdout}    CLI version
    Should Contain    ${result.stdout}    Runtime version
    Run And Expect RC Zero    dapr init
    Assert Command Output Contains    docker ps -f name=dapr_postgres    dapr_postgres
