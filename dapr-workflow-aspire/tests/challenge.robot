*** Settings ***
Name              Dapr Workflow Aspire
Documentation     Drift test for dapr-workflow-aspire: reconstruct the build-it-live
...               app from the assignments, build it, run it, assert the workflow completes.
Library           ../../tools/track-tester/libraries/assignment_blocks.py
Resource          ../../tools/track-tester/resources/workflow.resource
Variables         ../../tools/track-tester/variables/dapr_workflow_aspire.py
Suite Setup       Prepare Workdir
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${WORKDIR}        ${TEMPDIR}${/}eds-track
${SOLUTION_DIR}   ${WORKDIR}${/}EnterpriseDiagnostics
${LOG}            ${TEMPDIR}/dapr-workflow-aspire.log
${ASSIGN_1}       ${CURDIR}/../1-introduction/assignment.md
${ASSIGN_2}       ${CURDIR}/../2-project-creation/assignment.md
${ASSIGN_3}       ${CURDIR}/../3-workflow-definition/assignment.md
${ASSIGN_4}       ${CURDIR}/../4-apphost-resources/assignment.md
${ASSIGN_5}       ${CURDIR}/../5-run-application/assignment.md

*** Keywords ***
Prepare Workdir
    # Start from a clean working directory so reruns don't collide with a stale scaffold.
    Remove Directory    ${WORKDIR}    recursive=True
    Create Directory    ${WORKDIR}

*** Test Cases ***
Ch1 Install Aspire Templates
    # ch1 sets up the environment. The one drift-sensitive, environment-agnostic
    # step is pinning the Aspire project templates to a sandbox-compatible version
    # (the assignment warns NOT to use 13.4.*, which rejects the 0.0.0.0 binding
    # used later). Extract and run that pin from the assignment so it auto-follows
    # if the pinned version changes. The Aspire CLI install (`curl | bash`) and the
    # `source /root/.bashrc` shell reload are sandbox/CI provisioning, not run here.
    ${pin}=    Get Command Containing    ${ASSIGN_1}    Aspire.ProjectTemplates
    Run And Expect RC Zero    ${pin}

Ch2 Scaffold And Build
    # Scaffold runs in ${WORKDIR}; the assignment's `cd EnterpriseDiagnostics`
    # moves into the solution. Writes launchSettings.json, adds the pinned NuGet
    # packages, and builds. `aspire run` is skipped (launched only in Ch5).
    Apply Challenge    ${ASSIGN_2}    ${WORKDIR}    ${SOLUTION_DIR}    ${MANIFEST_CH2}
    File Should Contain
    ...    ${SOLUTION_DIR}/EnterpriseDiagnostics.ApiService/EnterpriseDiagnostics.ApiService.csproj
    ...    Dapr.Workflow

Ch3 Workflow Build
    # Creates the Models/Workflows/Activities folders + files and rebuilds.
    Apply Challenge    ${ASSIGN_3}    ${SOLUTION_DIR}    ${SOLUTION_DIR}    ${MANIFEST_CH3}

Ch4 AppHost Build
    # Writes the two Dapr component files, splices the <Content> item group into the
    # AppHost csproj, replaces AppHost.cs, and rebuilds.
    Apply Challenge    ${ASSIGN_4}    ${SOLUTION_DIR}    ${SOLUTION_DIR}    ${MANIFEST_CH4}

Ch5 Run And Assert
    [Teardown]    Stop Process With SIGINT    app
    # Launch `aspire run` (from the assignment) in the background; it starts the
    # ApiService + its Dapr sidecar. Skip the diagrid-dashboard docker step.
    ${aspire}=    Get Command Containing    ${ASSIGN_5}    aspire run
    Start Background Process    ${aspire}    ${LOG}    app    cwd=${SOLUTION_DIR}
    Wait Until App Responds    ${APISERVICE_URL}    timeout=240s
    # Start the workflow with the assignment's exact curl, then poll until the
    # output echoes the input stardate (present only once the workflow completes).
    ${start}=    Get Command Containing    ${ASSIGN_5}    /start
    Run And Expect RC Zero    ${start}
    Wait Until Command Output Contains    curl -s ${STATUS_URL}    ${EXPECTED_STARDATE}    timeout=120s
