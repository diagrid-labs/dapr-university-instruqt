*** Settings ***
Name              Ch6 Swap The Broker
Documentation     Drift test for dapr-pubsub page 6: RabbitMQ is started with the assignment's own
...               Run block (twice in a row, both must succeed), then demo 6 runs the demo 5 apps
...               against a `pubsub.rabbitmq` component. The same three orders give the same log
...               lines as page 5 (routed, 4 rejections, dead-lettered) and RabbitMQ shows the
...               exchanges and queues Dapr created, through the management API. The check scripts
...               of the page then pass against the running demo.
...
...               Demo 6 has no apps of its own, so they are built from the demo 5 folders. Their
...               logs land in the demo 5 app folders, but the suite reads the `dapr run` output.
...               The order IDs are unique per run.
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_pubsub.py
Suite Teardown    Run Keywords    Terminate All Processes    kill=True
...               AND    Run Process    docker rm -f rabbitmq    shell=True

*** Variables ***
${LOG}              ${TEMPDIR}/dapr-pubsub-ch6.log
${CH_DIR}           ${CURDIR}/..

*** Test Cases ***
Ports Are Free Before The Apps Start
    [Documentation]    A process leaked by a previous run squats a port and makes the next
    ...    `dapr run` fail with a bind error. Fail loudly here instead of inside the next test.
    FOR    ${port}    IN    5101    5102    5103    3510    3511    3512
        Port Should Be Free    ${port}
    END

RabbitMQ Block Is Safe To Run Twice
    [Documentation]    Review focus 4: the learner can run the block of step 1 again at any time.
    ...    The first failing check also says to start RabbitMQ when it is not there.
    Run Process    docker rm -f rabbitmq    shell=True
    ${check}=    Run Process    bash    ${CH_DIR}/scripts/check-rabbitmq-running.sh    stderr=STDOUT
    Should Be Equal As Integers    ${check.rc}    1
    Should Contain    ${check.stdout}    Start RabbitMQ
    Start RabbitMQ From The Assignment
    Start RabbitMQ From The Assignment
    ${check}=    Run Process    bash    ${CH_DIR}/scripts/check-rabbitmq-running.sh    stderr=STDOUT
    Should Be Equal As Integers    ${check.rc}    0    msg=${check.stdout}

DotNet Demo 6 Runs Demo 5 On RabbitMQ
    [Tags]    dotnet
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Run Keywords    Stop Process With SIGINT    app
    ...    AND    Run Keyword If Test Failed    Log File    ${LOG}
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO5}[dotnet]/${ORDER_API}[dotnet]
    Run And Expect RC Zero    dotnet build    ${PUBSUB_BASE}/dotnet/${DEMO5}[dotnet]/${SHIPPING}[dotnet]
    Walk Through Swap    dotnet

Python Demo 6 Runs Demo 5 On RabbitMQ
    [Tags]    python
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Run Keywords    Stop Process With SIGINT    app
    ...    AND    Run Keyword If Test Failed    Log File    ${LOG}
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO5}[python]/${ORDER_API}[python]
    Run And Expect RC Zero    uv sync    ${PUBSUB_BASE}/python/${DEMO5}[python]/${SHIPPING}[python]
    Walk Through Swap    python

Java Demo 6 Runs Demo 5 On RabbitMQ
    [Tags]    java
    [Setup]    Wait For The Ports To Be Free
    [Teardown]    Run Keywords    Stop Process With SIGINT    app
    ...    AND    Run Keyword If Test Failed    Log File    ${LOG}
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO5}[java]/${ORDER_API}[java]
    Run And Expect RC Zero    mvn -q -DskipTests package    ${PUBSUB_BASE}/java/${DEMO5}[java]/${SHIPPING}[java]
    Walk Through Swap    java    timeout=300s

*** Keywords ***
Port Should Be Free
    [Arguments]    ${port}
    # curl exits 7 (connection refused) when nothing is listening. rc 0 means something answered.
    ${result}=    Run Process    curl -s -o /dev/null http://localhost:${port}/    shell=True
    Should Not Be Equal As Integers    ${result.rc}    0
    ...    msg=Something is already listening on port ${port}. Stop the leaked app before running this suite.

Wait For The Ports To Be Free
    # The previous test's apps can take a moment to release the ports after SIGINT. Without this,
    # a readiness probe could be answered by the *previous* language's app.
    FOR    ${port}    IN    5101    5102    5103    3510    3511    3512
        Wait Until Keyword Succeeds    30s    1s    Port Should Be Free    ${port}
    END

Start RabbitMQ From The Assignment
    [Documentation]    Run the assignment's own RabbitMQ block (the one with `docker rm -f rabbitmq`),
    ...    so a change of the block or of the image tag is tested, not a copy of it.
    ${script}=    Evaluate
    ...    next(b for b in re.findall(r"```bash,run\\n(.*?)```", pathlib.Path(r"${CH_DIR}/assignment.md").read_text(), re.S) if "docker rm -f rabbitmq" in b)
    ...    modules=re, pathlib
    ${result}=    Run Process    bash    -c    ${script}    stderr=STDOUT    timeout=240s
    Should Be Equal As Integers    ${result.rc}    0    msg=The RabbitMQ block failed:\n${result.stdout}

Walk Through Swap
    [Arguments]    ${lang}    ${timeout}=180s
    ${demo_dir}=    Set Variable    ${PUBSUB_BASE}/${lang}/${DEMO6}[${lang}]
    # 1. RabbitMQ runs (started by the second test, restarted here so this test stands alone).
    Start RabbitMQ From The Assignment
    # 3. Demo 6 starts. Shipping's sidecar lists the express route once it has loaded the YAML.
    Start Background Process    dapr run -f .    ${LOG}    app    cwd=${demo_dir}
    Wait Until App Responds    http://localhost:5101/    ${timeout}
    Wait Until App Responds    http://localhost:5102/    ${timeout}
    Wait Until Command Output Contains    curl -s http://localhost:3511/v1.0/metadata    /orders/express    ${timeout}
    Assert Command Output Contains    curl -s http://localhost:3510/v1.0/metadata    pubsub.rabbitmq

    # 4. The same three orders as page 5. The assignment's IDs are o-6001 to o-6003, here they
    # carry a run prefix.
    ${run}=    Evaluate    "r" + str(int(time.time()))    modules=time
    ${r1}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${run}-6001","item":"coffee-beans","quantity":1,"priority":"standard"}'
    Should Contain    ${r1}    "orderId":"${run}-6001"
    Should Contain    ${r1}    "topic":"orders"
    ${r2}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${run}-6002","item":"coffee-beans","quantity":1,"priority":"express"}'
    Should Contain    ${r2}    "orderId":"${run}-6002"
    ${r3}=    Capture Command Output
    ...    curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d '{"orderId":"${run}-6003","item":"poison","quantity":1,"priority":"standard"}'
    Should Contain    ${r3}    "orderId":"${run}-6003"

    # 5. The same log as page 5: routing, 4 rejections, dead-lettering.
    Wait Until Log Contains    ${LOG}    shipping standard order ${run}-6001    ${timeout}
    Wait Until Log Contains    ${LOG}    shipping express order ${run}-6002    ${timeout}
    Wait Until Log Contains    ${LOG}    shipping dead-lettered order ${run}-6003    ${timeout}
    ${text}=    Get File    ${LOG}
    # First try plus 3 retries.
    ${rejected}=    Evaluate    len(re.findall(r'shipping rejected order ${run}-6003', $text))    modules=re
    Should Be Equal As Integers    ${rejected}    4
    Should Not Contain    ${text}    shipping dead-lettered order ${run}-6001
    Should Not Contain    ${text}    shipping dead-lettered order ${run}-6002
    Should Not Contain    ${text}    shipping rejected order ${run}-6001
    Should Not Contain    ${text}    shipping rejected order ${run}-6002

    # 5. What Dapr created in RabbitMQ, as the management API of the assignment shows it.
    ${exchanges}=    Capture Command Output
    ...    curl -s -u guest:guest http://localhost:15672/api/exchanges | jq -r '.[].name | select(startswith("orders"))' | sort
    Should Be Equal    ${exchanges}    orders\norders-dead
    ${queues}=    Capture Command Output
    ...    curl -s -u guest:guest http://localhost:15672/api/queues | jq -r '.[].name' | sort
    # The container is fresh, so Dapr created exactly these two queues (order-insensitive).
    Should Be Equal    ${queues}    shipping-orders\nshipping-orders-dead

    # 6. The check scripts of the page pass against the running demo.
    FOR    ${name}    IN    rabbitmq-running    apps-running    rabbitmq-component    dead-lettered
        ${check}=    Run Process    bash    ${CH_DIR}/scripts/check-${name}.sh    stderr=STDOUT    timeout=60s
        ...    env:TRACKS_SRC_DIR=${TRACKS_SRC_DIR}
        Should Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh failed:\n${check.stdout}
    END

# doc-sync coverage (the RabbitMQ block is extracted from the assignment and run as it is; the
# other commands are run above through keywords that build them from the language and the folder,
# or with a unique order prefix instead of the assignment's o-600x IDs):
#   docker rm -f rabbitmq >/dev/null 2>&1 || true
#   docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:4.4.0-management
#   for _ in $(seq 1 60); do
#     docker exec -u rabbitmq rabbitmq rabbitmq-diagnostics -q check_running >/dev/null 2>&1 &&
#       docker exec -u rabbitmq rabbitmq rabbitmq-diagnostics -q check_port_connectivity >/dev/null 2>&1 && break
#     sleep 1
#   done
#   cd /root/ai-agent-tracks-instruqt/pubsub
#   cd dotnet/Demo6-SwapProvider
#   cd python/demo6-swap-provider
#   cd java/demo6-swap-provider
#   dapr run -f .
#   for o in \
#     '{"orderId":"o-6001","item":"coffee-beans","quantity":1,"priority":"standard"}' \
#     '{"orderId":"o-6002","item":"coffee-beans","quantity":1,"priority":"express"}' \
#     '{"orderId":"o-6003","item":"poison","quantity":1,"priority":"standard"}'; do
#     curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d "$o"; echo
#   done
#   curl -s -u guest:guest http://localhost:15672/api/exchanges | jq -r '.[].name | select(startswith("orders"))' | sort
#   curl -s -u guest:guest http://localhost:15672/api/queues | jq -r '.[].name' | sort

# doc-sync coverage (the stop command of "Before you start" is for demos that Skip or Solve started
# in the background on the VM; the suite stops its own apps with Stop Process With SIGINT instead):
#   for f in /root/ai-agent-tracks-instruqt/pubsub/*/*/dapr.yaml; do (cd "$(dirname "$f")" && dapr stop -f . >/dev/null 2>&1); done; echo "No demo of this track is running now."
