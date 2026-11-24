*** Settings ***
Name              Ch3 Orchestrate With Aspire
Documentation     Drift test for dapr-workflow-aspire page 3: the learner writes apphost.cs with a heredoc,
...               starts the app with `aspire run` and looks at the resources in the Aspire dashboard and
...               the Dev Dashboard.
...
...               The suite starts from page 2's end state (rebuilt from pages 1 and 2 when SOLUTION_DIR
...               does not hold it), runs the page's Run blocks as they are (Apply Challenge), with the
...               VM's checkout path `/root/university-labs` swapped for TRACKS_SRC_DIR, and starts the
...               page's `aspire run` in the background, from the folder the page's `cd` names. Then the
...               page's check scripts must pass against the running app, the dashboard must list the
...               resources the page names (risk 4: statestore and engineering-dapr are hidden), the
...               page 2 check must not disturb the running app (Review Focus 3), and the page must
...               survive being applied again while the app runs.
...
...               The suite stops `aspire run` in its teardown, after saving the resources' logs.
...               SOLUTION_DIR stays in page 3's end state for the page 4 suite, which starts its own
...               `aspire run`.
Library           Collections
Library           OperatingSystem
Library           String
Library           ../../../tools/track-tester/libraries/assignment_blocks.py
Resource          ../../../tools/track-tester/resources/aspire.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_aspire.py
Suite Setup       Start From Page 2
Suite Teardown    Run Keywords
...               Capture Aspire Logs And Stop App    ${APPHOST}    ports=${APP_PORTS}
...               AND    Terminate All Processes    kill=True

*** Variables ***
${ASSIGNMENT}       ${CURDIR}/../assignment.md
${PAGE1}            ${CURDIR}/../../1-create-the-solution/assignment.md
${PAGE2}            ${CURDIR}/../../2-write-the-workflow/assignment.md
${CHECKS}           ${CURDIR}/../scripts
${PAGE2_CHECKS}     ${CURDIR}/../../2-write-the-workflow/scripts
@{NO_COPY_BLOCKS}
# The VM's checkout, as the page's `cd` names it.
${VM_CHECKOUT}      /root/university-labs
${APPHOST}          ${SOLUTION_DIR}${/}apphost.cs
${ENGINEERING}      ${SOLUTION_DIR}${/}Engineering
${LOG}              ${OUTPUT DIR}${/}aspire-run.log
# The engineering API, the Dev Dashboard and the Aspire dashboard.
@{APP_PORTS}        5411    9090    17000

*** Test Cases ***
The Checks Fail Before The Page
    # No apphost.cs at all, and the AppHost as `aspire new` created it (page 1): the apphost check
    # fails and names what is missing.
    ${empty}=    Set Variable    ${TEMPDIR}${/}workflow-aspire-ch3-empty
    Remove Directory    ${empty}    recursive=True
    Create Directory    ${empty}
    ${check}=    Run Check    apphost    ${empty}
    Should Not Be Equal As Integers    ${check.rc}    0    msg=check-apphost.sh passed on an empty workspace
    Create Directory    ${empty}${/}MeridianDiagnostics
    ${template}=    Get Generated AppHost
    Create File    ${empty}${/}MeridianDiagnostics${/}apphost.cs    ${template}
    ${check}=    Run Check    apphost    ${empty}
    Should Not Be Equal As Integers    ${check.rc}    0    msg=check-apphost.sh passed on the generated AppHost
    FOR    ${part}    IN    CommunityToolkit.Aspire.Hosting.Dapr    statestore    engineering    dev-dashboard
        Should Contain    ${check.stdout}    ${part}
    END
    # Nothing runs yet, so neither the app nor the Dev Dashboard answers.
    FOR    ${name}    IN    api    dev-dashboard
        ${check}=    Run Check    ${name}
        Should Not Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh passed before aspire run:\n${check.stdout}
        Should Contain    ${check.stdout}    does not answer
    END
    [Teardown]    Remove Directory    ${empty}    recursive=True

The Page Writes The AppHost
    Apply Page 3
    ${check}=    Run Check    apphost
    Should Be Equal As Integers    ${check.rc}    0    msg=check-apphost.sh failed:\n${check.stdout}
    ${apphost}=    Get File    ${APPHOST}
    # Both Aspire packages at the CLI's pin (versions.hcl).
    Should Contain    ${apphost}    \#:package Aspire.Hosting.AppHost@${ASPIRE_CLI_VERSION}\n
    Should Contain    ${apphost}    \#:package Aspire.Hosting.Dotnet@${ASPIRE_CLI_VERSION}\n
    # The ports the checks, the tabs and page 4 rely on.
    FOR    ${text}    IN
    ...    .WithMetadata("actorStateStore", "true")
    ...    .WithHttpEndpoint(port: 5411, name: "api")
    ...    .WithDaprSidecar(sidecar => sidecar.WithReference(stateStore))
    ...    "--port", "9090", "--bind", "0.0.0.0", "--no-open", "--mode", "aspire"
    ...    .WithHttpEndpoint(port: 9090, isProxied: false)
        Should Contain    ${apphost}    ${text}
    END

Aspire Run Starts The App
    # The page's own `aspire run`, from the folder its `cd` names (the workspace). The workspace is
    # in the university-labs checkout, whose .gitignore leaves out MeridianDiagnostics/, and the CLI
    # only searches git-tracked files for an AppHost, so the page names it with --apphost.
    ${aspire}=    Get Command Containing    ${ASSIGNMENT}    aspire run
    Start Aspire Run    ${aspire}    ${WORKSPACE}    ${LOG}
    Wait Until App Responds    ${APP_URL}    timeout=240s
    Wait Until Loopback Host Answers    ${DEV_DASHBOARD_URL}/api/workflows    localhost:9090
    The Page 3 Checks Pass
    # The banner lines the page shows as the expected output.
    ${log}=    Get Aspire Run Output
    FOR    ${text}    IN    AppHost:    MeridianDiagnostics/apphost.cs    Dashboard:    http://localhost:17000
    ...    Press CTRL+C to stop the AppHost and exit.
        Should Contain    ${log}    ${text}
        Assignment Should Contain    ${text}
    END

The Dashboard Lists The Resources The Page Names
    [Documentation]    Risk 4: by default the dashboard shows engineering, engineering-dapr-cli and
    ...    dev-dashboard; statestore and engineering-dapr only show with Show hidden resources. The
    ...    page names exactly those.
    ${visible}=    Aspire Resources    ${APPHOST}
    Should Be Equal    ${visible}    ${{ ['dev-dashboard', 'engineering', 'engineering-dapr-cli'] }}
    ${all}=    Aspire Resources    ${APPHOST}    hidden=${True}
    FOR    ${name}    IN    statestore    engineering-dapr
        List Should Contain Value    ${all}    ${name}
        List Should Not Contain Value    ${visible}    ${name}
    END
    FOR    ${text}    IN    `engineering`, of type **Project**    `engineering-dapr-cli`, of type **Executable**
    ...    `dev-dashboard`, of type **Executable**    **Show hidden resources**
        Assignment Should Contain    ${text}
    END

The Dev Dashboard Finds The Engineering App
    # --mode aspire: the Dev Dashboard discovers the app that Aspire runs, with its sidecar.
    ${apps}=    Capture Command Output    curl -sf -H 'Host: localhost:9090' ${DEV_DASHBOARD_URL}/api/apps
    ${engineering}=    Evaluate    [a for a in json.loads($apps) if a["appId"] == "engineering"]    modules=json
    Length Should Be    ${engineering}    1
    Should Be True    ${engineering}[0][isAspire]
    Should Be True    ${engineering}[0][sidecarReachable]

The Page 2 Check Leaves The Running App Alone
    [Documentation]    Review Focus 3: the learner goes back to page 2 and selects Check while
    ...    `aspire run` runs. The checks pass, there is no file lock error, the app keeps its process and
    ...    its bin/ folder, and it still answers.
    ${pid}=    Aspire Resource Pid    ${APPHOST}    engineering
    ${dll}=    Set Variable    ${ENGINEERING}${/}bin${/}Debug${/}net10.0${/}Engineering.dll
    ${before}=    Get Modified Time    ${dll}    epoch
    # The learner went back and saved Activities.cs again, so a build into bin/ would rewrite the DLL.
    Sleep    1s
    Touch    ${ENGINEERING}${/}Activities.cs
    FOR    ${name}    IN    workflow    activities    program    build
        ${check}=    Run Process    bash    ${PAGE2_CHECKS}${/}check-${name}.sh    stderr=STDOUT    timeout=120s
        ...    env:WORKSPACE=${WORKSPACE}
        Should Be Equal As Integers    ${check.rc}    0    msg=page 2 check-${name}.sh failed while Aspire runs:\n${check.stdout}
    END
    ${after}=    Get Modified Time    ${dll}    epoch
    Should Be Equal    ${before}    ${after}    msg=the page 2 build check rewrote ${dll} under the running app
    ${pid_after}=    Aspire Resource Pid    ${APPHOST}    engineering
    Should Be Equal    ${pid}    ${pid_after}    msg=engineering restarted during the page 2 check
    The Page 3 Checks Pass

The Page Can Be Applied Again While The App Runs
    [Documentation]    The learner presses the page's Run buttons again (except `aspire run`, which
    ...    already runs). apphost.cs gets the same content, the running app keeps its process, and the
    ...    checks still pass.
    ${first}=    Get File    ${APPHOST}
    ${pid}=    Aspire Resource Pid    ${APPHOST}    engineering
    Apply Page 3
    ${second}=    Get File    ${APPHOST}
    Should Be Equal    ${first}    ${second}
    Sleep    5s    reason=give Aspire time to react to the rewritten apphost.cs, if it did
    ${pid_after}=    Aspire Resource Pid    ${APPHOST}    engineering
    Should Be Equal    ${pid}    ${pid_after}    msg=engineering restarted after apphost.cs was written again
    The Page 3 Checks Pass

*** Keywords ***
Start From Page 2
    # Page 3 starts where page 2 ends. When the page 2 suite did not run first (a local run of this
    # suite alone), rebuild pages 1 and 2 from their assignments. (Robot variables ignore case, so
    # the flags must not be named like ${PAGE1} and ${PAGE2}.)
    ${has_profile}=    Run Keyword And Return Status    File Should Exist    ${SOLUTION_DIR}${/}apphost.run.json
    ${has_project}=    Run Keyword And Return Status    File Should Exist    ${ENGINEERING}${/}Engineering.csproj
    IF    not ${has_profile} or not ${has_project}
        Remove Directory    ${SOLUTION_DIR}    recursive=True
        Apply Challenge    ${PAGE1}    ${WORKSPACE}    ${SOLUTION_DIR}    ${NO_COPY_BLOCKS}
        ...    rewrite_from=${VM_CHECKOUT}    rewrite_to=${TRACKS_SRC_DIR}
    END
    ${has_workflow}=    Run Keyword And Return Status    File Should Exist    ${ENGINEERING}${/}DiagnosticsWorkflow.cs
    ${built}=    Run Keyword And Return Status    File Should Exist
    ...    ${ENGINEERING}${/}bin${/}Debug${/}net10.0${/}Engineering.dll
    IF    not ${has_workflow} or not ${built}
        Apply Challenge    ${PAGE2}    ${WORKSPACE}    ${SOLUTION_DIR}    ${MANIFEST_PAGE2}
        ...    rewrite_from=${VM_CHECKOUT}    rewrite_to=${TRACKS_SRC_DIR}
    END

Apply Page 3
    # Every Run block in page order, except `aspire run` (Apply Challenge skips it; the suite starts
    # it in the background). The page has no ,copy blocks.
    Apply Challenge    ${ASSIGNMENT}    ${WORKSPACE}    ${SOLUTION_DIR}    ${NO_COPY_BLOCKS}
    ...    rewrite_from=${VM_CHECKOUT}    rewrite_to=${TRACKS_SRC_DIR}

Get Generated AppHost
    # The apphost.cs that `aspire new aspire-empty` creates, as page 1 shows it.
    ${page_one}=    Get File    ${PAGE1}
    ${apphost}=    Evaluate    re.search(r"```csharp,nocopy\\n(#:package Aspire.*?)```", $page_one, re.S).group(1)
    ...    modules=re
    RETURN    ${apphost}

Get Aspire Run Output
    # The output of `aspire run` without its colours and terminal hyperlinks (CSI and OSC 8 escape
    # sequences), as the learner reads it. Written without backslashes: Robot strips them.
    ${log}=    Get File    ${LOG}
    ${esc}=    Evaluate    chr(27)
    ${plain}=    Evaluate    re.sub($esc + ".[0-9;?]*[A-Za-z]", "", re.sub($esc + ".8;[^" + $esc + "]*" + $esc + ".", "", $log))
    ...    modules=re
    RETURN    ${plain}

Assignment Should Contain
    [Arguments]    ${text}
    ${page}=    Get File    ${ASSIGNMENT}
    Should Contain    ${page}    ${text}    msg=page 3 does not show: ${text}

Run Check
    [Arguments]    ${name}    ${workspace}=${WORKSPACE}
    ${check}=    Run Process    bash    ${CHECKS}${/}check-${name}.sh    stderr=STDOUT    timeout=60s
    ...    env:WORKSPACE=${workspace}
    RETURN    ${check}

The Page 3 Checks Pass
    FOR    ${name}    IN    apphost    api    dev-dashboard
        ${check}=    Run Check    ${name}
        Should Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh failed:\n${check.stdout}
    END

# doc-sync coverage: Apply Page 3 runs every Run block of the page but `aspire run` (in ${WORKSPACE},
# after the cd), and "Aspire Run Starts The App" starts the page's `aspire run` from ${WORKSPACE}:
#   cd /root/university-labs/workflow-aspire
#   aspire run --apphost MeridianDiagnostics/apphost.cs
#   cat > MeridianDiagnostics/apphost.cs <<'EOF'
#   #:package Aspire.Hosting.AppHost@17.0.0
#   #:package Aspire.Hosting.Dotnet@17.0.0
#   #:package CommunityToolkit.Aspire.Hosting.Dapr@13.0.0
#
#   using CommunityToolkit.Aspire.Hosting.Dapr;
#
#   var builder = DistributedApplication.CreateBuilder(args);
#
#   // The workflow state store: the Redis container that `dapr init` started.
#   var stateStore = builder.AddDaprComponent("statestore", "state.redis")
#       .WithMetadata("redisHost", "localhost:6379")
#       .WithMetadata("actorStateStore", "true");
#
#   builder.AddDotnetProject("engineering", "./Engineering/Engineering.csproj")
#       .WithHttpEndpoint(port: 5411, name: "api")
#       .WithDaprSidecar(sidecar => sidecar.WithReference(stateStore));
#
#   builder.AddExecutable("dev-dashboard", "diagrid-dev-dashboard", ".",
#           "--port", "9090", "--bind", "0.0.0.0", "--no-open", "--mode", "aspire")
#       .WithHttpEndpoint(port: 9090, isProxied: false);
#
#   builder.Build().Run();
#   EOF
