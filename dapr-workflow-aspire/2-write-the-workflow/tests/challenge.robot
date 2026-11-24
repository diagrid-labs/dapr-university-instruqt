*** Settings ***
Name              Ch2 Write The Workflow
Documentation     Drift test for dapr-workflow-aspire page 2: the learner pastes DiagnosticsWorkflow.cs and
...               Activities.cs into the Engineering project, writes Program.cs with a heredoc and builds
...               the project.
...
...               The suite starts from page 1's end state (rebuilt from page 1's assignment when
...               SOLUTION_DIR is missing), writes the page's two ,copy blocks with MANIFEST_PAGE2 and
...               runs its Run blocks as they are (Apply Challenge), with the VM's checkout path
...               `/root/university-labs` swapped for TRACKS_SRC_DIR. Then the page's check scripts
...               must pass, without touching Engineering/bin. The checks must fail on an empty
...               workspace, the page must survive being applied twice (Review Focus 1), and a broken
...               paste must fail with the message for its file, not a generic build error (Review
...               Focus 2).
...
...               It leaves SOLUTION_DIR in page 2's end state for the page 3 suite.
Library           Collections
Library           OperatingSystem
Library           String
Library           ../../../tools/track-tester/libraries/assignment_blocks.py
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_aspire.py
Suite Setup       Start From Page 1
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${ASSIGNMENT}       ${CURDIR}/../assignment.md
${PAGE1}            ${CURDIR}/../../1-create-the-solution/assignment.md
${CHECKS}           ${CURDIR}/../scripts
@{NO_COPY_BLOCKS}
# The VM's checkout, as the page's `cd` names it.
${VM_CHECKOUT}      /root/university-labs
${ENGINEERING}      ${SOLUTION_DIR}${/}Engineering

*** Test Cases ***
The Checks Fail On An Empty Workspace
    ${empty}=    Set Variable    ${TEMPDIR}${/}workflow-aspire-ch2-empty
    Remove Directory    ${empty}    recursive=True
    Create Directory    ${empty}
    FOR    ${name}    IN    workflow    activities    program
        ${check}=    Run Check    ${name}    ${empty}
        Should Not Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh passed on an empty workspace
    END
    # The build check leaves a missing project to the page 1 check and the missing files to the
    # file checks, so the learner sees one hint per problem.
    ${check}=    Run Check    build    ${empty}
    Should Be Equal As Integers    ${check.rc}    0    msg=check-build.sh failed on an empty workspace:\n${check.stdout}
    [Teardown]    Remove Directory    ${empty}    recursive=True

The Page Writes The Workflow
    Apply Page 2
    The Page 2 Checks Pass
    # The API contract the later pages rely on.
    ${workflow}=    Get File    ${ENGINEERING}${/}DiagnosticsWorkflow.cs
    FOR    ${text}    IN
    ...    public record DiagnosticsOutput(string StarDate, string Priority, string Summary, bool BridgeNotified);
    ...    class DiagnosticsWorkflow : Workflow<DiagnosticsInput, DiagnosticsOutput>
    ...    ["WarpCore", "LifeSupport", "Shields"]
    ...    context.CreateTimer(TimeSpan.FromSeconds(15))
    ...    context.CreateReplaySafeLogger<DiagnosticsWorkflow>()
    ...    if (priority == "Urgent")
        Should Contain    ${workflow}    ${text}
    END
    # Deterministic: nothing in the workflow that differs between a run and its replay.
    FOR    ${text}    IN    Random    DateTime    Guid.NewGuid    Task.Delay    HttpClient
        Should Not Contain    ${workflow}    ${text}
    END
    ${program}=    Get File    ${ENGINEERING}${/}Program.cs
    FOR    ${type}    IN    RegisterWorkflow<DiagnosticsWorkflow>    RegisterActivity<DiagnoseSubsystemActivity>
    ...    RegisterActivity<PrioritizeDiagnosticsActivity>    RegisterActivity<NotifyBridgeActivity>
    ...    app.MapPost("/start"    app.MapGet("/status/{id}"
        Should Contain    ${program}    ${type}
    END
    # The page's dotnet build ran: the app is in bin/.
    File Should Exist    ${ENGINEERING}${/}bin${/}Debug${/}net10.0${/}Engineering.dll

The Build Check Leaves Engineering Bin Alone
    [Documentation]    Risk 5: the check builds into a temporary folder without restoring, so a running
    ...    `aspire run` keeps its bin/ folder. The DLL that the page's build wrote stays as it is.
    ${dll}=    Set Variable    ${ENGINEERING}${/}bin${/}Debug${/}net10.0${/}Engineering.dll
    ${before}=    Get Modified Time    ${dll}    epoch
    Sleep    1s
    ${check}=    Run Check    build
    Should Be Equal As Integers    ${check.rc}    0    msg=check-build.sh failed:\n${check.stdout}
    ${after}=    Get Modified Time    ${dll}    epoch
    Should Be Equal    ${before}    ${after}    msg=check-build.sh rewrote ${dll}

The Officers Are The Meridian Crew
    # AGENTS.md "The ISV Meridian story": the four crew members, and no other names.
    ${activities}=    Get File    ${ENGINEERING}${/}Activities.cs
    ${officers}=    Evaluate
    ...    re.findall(r'"([^"]+)"', re.search(r'Officers\\s*=\\s*\\[(.*?)\\];', $activities, re.S).group(1))
    ...    modules=re
    Should Be Equal    ${officers}
    ...    ${{ ['Captain Ilsa Varn', 'Commander Anja Lindqvist', 'Lieutenant Commander Dayo Okafor', 'Ensign Mira Varga'] }}
    # The page names the same four.
    ${page}=    Get File    ${ASSIGNMENT}
    Should Contain    ${page}    Captain Ilsa Varn, Commander Anja Lindqvist, Lieutenant Commander Dayo Okafor or Ensign Mira Varga

The Page Can Be Applied Twice
    [Documentation]    Review Focus 1: a learner pastes the blocks and presses every Run button of the page
    ...    again. The files get the same content, and the checks still pass.
    ${first}=    Get Engineering Sources
    Apply Page 2
    ${second}=    Get Engineering Sources
    Should Be Equal    ${first}    ${second}
    ${files}=    List Files In Directory    ${ENGINEERING}    *.cs
    Sort List    ${files}
    Should Be Equal    ${files}    ${{ ['Activities.cs', 'DiagnosticsWorkflow.cs', 'Program.cs'] }}
    The Page 2 Checks Pass

A Half-Pasted Activities File Fails The Build Check With Its Name
    [Documentation]    Review Focus 2: the learner copied Activities.cs without its last lines. All three
    ...    classes are there, so the file check passes, and the build check fails naming Activities.cs.
    ${good}=    Get File    ${ENGINEERING}${/}Activities.cs
    ${lines}=    Split To Lines    ${good.rstrip()}
    ${half}=    Catenate    SEPARATOR=\n    @{lines}[:-3]
    Create File    ${ENGINEERING}${/}Activities.cs    ${half}\n
    ${check}=    Run Check    activities
    Should Be Equal As Integers    ${check.rc}    0    msg=check-activities.sh failed:\n${check.stdout}
    ${check}=    Run Check    build
    Should Not Be Equal As Integers    ${check.rc}    0    msg=check-build.sh passed on a half-pasted Activities.cs
    Should Contain    ${check.stdout}    The Engineering project does not build.
    Should Contain    ${check.stdout}    Errors in: Activities.cs\n
    [Teardown]    Create File    ${ENGINEERING}${/}Activities.cs    ${good}

The Workflow Pasted Into Activities Fails With The Activities Message
    [Documentation]    Review Focus 2: the learner pasted the workflow block into Activities.cs. The
    ...    activities check names the missing classes, and the build check stays quiet (one hint).
    ${good}=    Get File    ${ENGINEERING}${/}Activities.cs
    Copy File    ${ENGINEERING}${/}DiagnosticsWorkflow.cs    ${ENGINEERING}${/}Activities.cs
    ${check}=    Run Check    activities
    Should Not Be Equal As Integers    ${check.rc}    0
    Should Contain    ${check.stdout}    DiagnoseSubsystemActivity PrioritizeDiagnosticsActivity NotifyBridgeActivity
    ${check}=    Run Check    build
    Should Be Equal As Integers    ${check.rc}    0    msg=check-build.sh reported a build error:\n${check.stdout}
    [Teardown]    Create File    ${ENGINEERING}${/}Activities.cs    ${good}

The Checks Pass Again After The Fixes
    The Page 2 Checks Pass

*** Keywords ***
Start From Page 1
    # Page 2 starts where page 1 ends. When the page 1 suite did not run first (a local run of this
    # suite alone), rebuild page 1 from its assignment.
    ${ready}=    Run Keyword And Return Status    File Should Exist    ${SOLUTION_DIR}${/}apphost.run.json
    ${has_project}=    Run Keyword And Return Status    File Should Exist    ${ENGINEERING}${/}Engineering.csproj
    IF    not ${ready} or not ${has_project}
        Remove Directory    ${SOLUTION_DIR}    recursive=True
        Apply Challenge    ${PAGE1}    ${WORKSPACE}    ${SOLUTION_DIR}    ${NO_COPY_BLOCKS}
        ...    rewrite_from=${VM_CHECKOUT}    rewrite_to=${TRACKS_SRC_DIR}
    END

Apply Page 2
    # The two ,copy blocks into their files (MANIFEST_PAGE2) and every Run block, in page order.
    Apply Challenge    ${ASSIGNMENT}    ${WORKSPACE}    ${SOLUTION_DIR}    ${MANIFEST_PAGE2}
    ...    rewrite_from=${VM_CHECKOUT}    rewrite_to=${TRACKS_SRC_DIR}

Get Engineering Sources
    ${sources}=    Create Dictionary
    FOR    ${name}    IN    DiagnosticsWorkflow.cs    Activities.cs    Program.cs
        ${body}=    Get File    ${ENGINEERING}${/}${name}
        Set To Dictionary    ${sources}    ${name}=${body}
    END
    RETURN    ${sources}

Run Check
    [Arguments]    ${name}    ${workspace}=${WORKSPACE}
    ${check}=    Run Process    bash    ${CHECKS}${/}check-${name}.sh    stderr=STDOUT    timeout=120s
    ...    env:WORKSPACE=${workspace}
    RETURN    ${check}

The Page 2 Checks Pass
    FOR    ${name}    IN    workflow    activities    program    build
        ${check}=    Run Check    ${name}
        Should Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh failed:\n${check.stdout}
    END

# doc-sync coverage: Apply Page 2 runs every Run block of the page (in ${WORKSPACE}, after each anchored cd):
#   cd /root/university-labs/workflow-aspire
#   cat > MeridianDiagnostics/Engineering/Program.cs <<'EOF'
#   using Dapr.Workflow;
#
#   var builder = WebApplication.CreateBuilder(args);
#
#   builder.Services.AddDaprWorkflow(options =>
#   {
#       options.RegisterWorkflow<DiagnosticsWorkflow>();
#       options.RegisterActivity<DiagnoseSubsystemActivity>();
#       options.RegisterActivity<PrioritizeDiagnosticsActivity>();
#       options.RegisterActivity<NotifyBridgeActivity>();
#   });
#
#   var app = builder.Build();
#
#   app.MapPost("/start", async (DiagnosticsInput input, DaprWorkflowClient client) =>
#   {
#       var instanceId = await client.ScheduleNewWorkflowAsync(nameof(DiagnosticsWorkflow), input.Id, input);
#       return Results.Ok(new { instanceId });
#   });
#
#   app.MapGet("/status/{id}", async (string id, DaprWorkflowClient client) =>
#   {
#       var state = await client.GetWorkflowStateAsync(id);
#       if (state is null || !state.Exists)
#       {
#           return Results.NotFound();
#       }
#       return Results.Ok(new
#       {
#           status = state.RuntimeStatus.ToString(),
#           output = state.RuntimeStatus == WorkflowRuntimeStatus.Completed
#               ? state.ReadOutputAs<DiagnosticsOutput>()
#               : null
#       });
#   });
#
#   app.Run();
#   EOF
#   dotnet build MeridianDiagnostics/Engineering
