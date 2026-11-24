# Keywords for suites that run an Aspire AppHost with `aspire run` (dapr-workflow-aspire pages 3 and 4).
# Imports the generic process keywords from dapr.resource.

*** Settings ***
Resource    dapr.resource

*** Keywords ***
Start Aspire Run
    # Start the page's `aspire run` command in the background under ${alias}. `exec` makes the shell
    # become the CLI, so Stop Process With SIGINT reaches it (see Start Background Process). Robot
    # starts the process in its own session, where the CLI takes a group SIGINT like a terminal's
    # Ctrl+C and stops every resource.
    [Arguments]    ${command}    ${cwd}    ${logfile}    ${alias}=aspire
    Should Start With    ${command}    aspire run    msg=Not an aspire run command: ${command}
    Start Background Process    exec ${command}    ${logfile}    ${alias}    cwd=${cwd}

Wait Until Loopback Host Answers
    # The Dev Dashboard binds 0.0.0.0 and only answers a loopback Host header (as the lab's Dev
    # Dashboard tab sends). Poll ${url} with that header until it answers with a 2xx status.
    [Arguments]    ${url}    ${host}    ${timeout}=120s
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Run And Expect RC Zero    curl -sf -o /dev/null --max-time 5 -H 'Host: ${host}' ${url}

Aspire Resources
    # The display names of the running AppHost's resources, as `aspire describe` lists them: the
    # ones the dashboard shows by default, or every resource with ${hidden}=${True}.
    [Arguments]    ${apphost}    ${hidden}=${False}
    ${args}=    Create List    describe    --apphost    ${apphost}    --format    Json
    ...    --non-interactive    --nologo
    IF    ${hidden}    Append To List    ${args}    --include-hidden
    ${r}=    Run Process    aspire    @{args}    timeout=60s
    Should Be Equal As Integers    ${r.rc}    0    msg=aspire describe failed:\n${r.stdout}\n${r.stderr}
    ${names}=    Evaluate    sorted(r["displayName"] for r in json.loads($r.stdout)["resources"])
    ...    modules=json
    RETURN    ${names}

Aspire Resource Pid
    # The process ID of one resource (a Project or an Executable) in the running AppHost.
    [Arguments]    ${apphost}    ${name}
    ${r}=    Run Process    aspire    describe    --apphost    ${apphost}    --format    Json
    ...    --non-interactive    --nologo    timeout=60s
    Should Be Equal As Integers    ${r.rc}    0    msg=aspire describe failed:\n${r.stdout}\n${r.stderr}
    # A lambda, because a generator in Evaluate cannot see Robot variables such as $name.
    ${pid}=    Evaluate
    ...    (lambda n, d: [x["properties"]["executable.pid"] for x in d["resources"] if x["displayName"] == n][0])($name, json.loads($r.stdout))
    ...    modules=json
    RETURN    ${pid}

Capture Aspire Logs And Stop App
    # For teardowns. `aspire run` prints only its banner, so its own log never shows the resources'
    # output. While the AppHost still runs, save every resource's console logs (the app, its Dapr
    # sidecar, the Dev Dashboard) and an Aspire export (logs and telemetry) next to the report. Runs
    # on pass and fail, so a failing run can be compared with a passing one. A capture error never
    # fails the teardown. Then stop `aspire run` and wait until the AppHost's ports are free, so the
    # next suite can start its own.
    [Arguments]    ${apphost}    ${alias}=aspire    ${ports}=${{ [] }}
    ${running}=    Run Keyword And Return Status    Process Should Be Running    ${alias}
    IF    ${running}
        Run Keyword And Ignore Error    Run Process    aspire    logs    --apphost    ${apphost}
        ...    --timestamps    --include-hidden    --non-interactive    --nologo
        ...    stdout=${OUTPUT DIR}${/}aspire-resources.log    stderr=STDOUT    timeout=60s
        Run Keyword And Ignore Error    Run Process    aspire    export    --apphost    ${apphost}
        ...    --include-hidden    --non-interactive    --nologo    --output    ${OUTPUT DIR}${/}aspire-export.zip
        ...    stdout=${OUTPUT DIR}${/}aspire-export.log    stderr=STDOUT    timeout=120s
    END
    Stop Process With SIGINT If Running    ${alias}    timeout=30s
    FOR    ${port}    IN    @{ports}
        Wait Until Keyword Succeeds    60s    2s
        ...    Run And Expect RC Zero    ! curl -s -o /dev/null --max-time 2 http://localhost:${port}
    END
