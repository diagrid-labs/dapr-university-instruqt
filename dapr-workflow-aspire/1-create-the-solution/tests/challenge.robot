*** Settings ***
Name              Ch1 Create The Solution
Documentation     Drift test for dapr-workflow-aspire page 1: the learner creates the MeridianDiagnostics
...               solution with `aspire new aspire-empty`, adds the Engineering web project with the
...               Dapr.Workflow package and writes apphost.run.json with a heredoc.
...
...               The suite runs the page's Run blocks as they are (Apply Challenge), with the VM's
...               checkout path `/root/university-labs` swapped for TRACKS_SRC_DIR, in a clean
...               workspace. Then the page's check scripts must pass. The checks must fail on an empty
...               workspace, and the page must survive being applied twice (Review Focus 1: no
...               `MeridianDiagnostics-2`, no error from `aspire new` or `dotnet new`).
...
...               It leaves SOLUTION_DIR in page 1's end state for the page 2 suite.
Library           Collections
Library           OperatingSystem
Library           ../../../tools/track-tester/libraries/assignment_blocks.py
Resource          ../../../tools/track-tester/resources/dapr.resource
Variables         ../../../tools/track-tester/variables/dapr_workflow_aspire.py
Suite Setup       Start From An Empty Workspace
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${ASSIGNMENT}       ${CURDIR}/../assignment.md
${CHECKS}           ${CURDIR}/../scripts
@{NO_COPY_BLOCKS}
# The VM's checkout, as the page's `cd` names it.
${VM_CHECKOUT}      /root/university-labs

*** Test Cases ***
The Aspire CLI Is At The Pin
    ${result}=    Run And Expect RC Zero    aspire --version
    Should Start With    ${result.stdout.strip()}    ${ASPIRE_CLI_VERSION}+
    # The page's expected output shows the same version.
    ${page}=    Get File    ${ASSIGNMENT}
    Should Contain    ${page}    \n${ASPIRE_CLI_VERSION}+

The Checks Fail On An Empty Workspace
    ${empty}=    Set Variable    ${TEMPDIR}${/}workflow-aspire-ch1-empty
    Remove Directory    ${empty}    recursive=True
    Create Directory    ${empty}
    FOR    ${name}    IN    solution    engineering    launch-profile
        ${check}=    Run Check    ${name}    ${empty}
        Should Not Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh passed on an empty workspace
    END
    [Teardown]    Remove Directory    ${empty}    recursive=True

The Page Builds The Solution
    Apply Page 1
    The Page 1 Checks Pass
    # What section 2 says the template creates, and the apphost.cs section 5 shows.
    FOR    ${file}    IN    .vscode/extensions.json    apphost.cs    apphost.run.json    aspire.config.json
        File Should Exist    ${SOLUTION_DIR}${/}${file}
    END
    File Should Contain    ${SOLUTION_DIR}${/}aspire.config.json    apphost.cs
    ${apphost}=    Get File    ${SOLUTION_DIR}${/}apphost.cs
    ${page}=    Get File    ${ASSIGNMENT}
    Should Contain    ${page}    ${apphost.strip()}    msg=The generated apphost.cs differs from the one section 5 shows:\n${apphost}
    File Should Contain    ${SOLUTION_DIR}${/}Engineering${/}Engineering.csproj
    ...    <PackageReference Include="Dapr.Workflow" Version="1.19.1" />

The Launch Profile Opens The Dashboard To The Sandbox
    ${json}=    Get File    ${SOLUTION_DIR}${/}apphost.run.json
    ${run}=    Evaluate    json.loads($json)    modules=json
    ${profiles}=    Get Dictionary Keys    ${run}[profiles]
    Should Be Equal    ${profiles}    ${{ ['http'] }}
    ${http}=    Set Variable    ${run}[profiles][http]
    Should Be Equal    ${http}[applicationUrl]    http://0.0.0.0:17000
    Should Be Equal    ${http}[launchBrowser]    ${False}
    ${env}=    Set Variable    ${http}[environmentVariables]
    # The resource service must stay on loopback, or the AppHost stops.
    Should Be Equal    ${env}[ASPIRE_RESOURCE_SERVICE_ENDPOINT_URL]    http://localhost:17003
    Should Be Equal    ${env}[ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL]    http://localhost:17001
    Should Be Equal    ${env}[ASPIRE_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS]    true
    Should Be Equal    ${env}[ASPIRE_ALLOW_UNSECURED_TRANSPORT]    true
    # Risk 3: Aspire 17 needs only one of the anonymous-access names; the page keeps the Aspire one.
    Dictionary Should Not Contain Key    ${env}    DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS

The Page Can Be Applied Twice
    [Documentation]    Review Focus 1: a learner presses every Run button of the page again. The
    ...    guarded `aspire new` and `dotnet new web` skip, `dotnet add package` and the heredoc give
    ...    the same result, and no second solution or project folder appears.
    Apply Page 1
    ${dirs}=    List Directories In Directory    ${WORKSPACE}
    Should Be Equal    ${dirs}    ${{ ['MeridianDiagnostics'] }}
    ${projects}=    List Directories In Directory    ${SOLUTION_DIR}    pattern=Engineering*
    Should Be Equal    ${projects}    ${{ ['Engineering'] }}
    ${refs}=    Grep File    ${SOLUTION_DIR}${/}Engineering${/}Engineering.csproj    Dapr.Workflow
    ${lines}=    Get Line Count    ${refs}
    Should Be Equal As Integers    ${lines}    1    msg=Dapr.Workflow is referenced more than once:\n${refs}
    The Page 1 Checks Pass

*** Keywords ***
Start From An Empty Workspace
    # Page 1 starts from the workspace as the module clones it: README.md and .gitignore only.
    Directory Should Exist    ${WORKSPACE}
    Remove Directory    ${SOLUTION_DIR}    recursive=True

Apply Page 1
    # Every Run block of the page, in order, as the page shows it (heredoc included).
    Apply Challenge    ${ASSIGNMENT}    ${WORKSPACE}    ${SOLUTION_DIR}    ${NO_COPY_BLOCKS}
    ...    rewrite_from=${VM_CHECKOUT}    rewrite_to=${TRACKS_SRC_DIR}

Run Check
    [Arguments]    ${name}    ${workspace}=${WORKSPACE}
    ${check}=    Run Process    bash    ${CHECKS}${/}check-${name}.sh    stderr=STDOUT    timeout=60s
    ...    env:WORKSPACE=${workspace}
    RETURN    ${check}

The Page 1 Checks Pass
    FOR    ${name}    IN    solution    engineering    dapr-workflow    launch-profile
        ${check}=    Run Check    ${name}
        Should Be Equal As Integers    ${check.rc}    0    msg=check-${name}.sh failed:\n${check.stdout}
    END

# doc-sync coverage: Apply Page 1 runs every Run block of the page (in ${WORKSPACE}, after each anchored cd):
#   cd /root/university-labs/workflow-aspire
#   aspire --version
#   [ -d MeridianDiagnostics ] || aspire new aspire-empty --version 17.0.0 --name MeridianDiagnostics --output MeridianDiagnostics --non-interactive --agents none --nologo
#   [ -d MeridianDiagnostics/Engineering ] || dotnet new web -n Engineering -o MeridianDiagnostics/Engineering
#   dotnet add MeridianDiagnostics/Engineering package Dapr.Workflow --version 1.19.1
#   cat > MeridianDiagnostics/apphost.run.json <<'EOF'
#   {
#     "$schema": "https://json.schemastore.org/launchsettings.json",
#     "profiles": {
#       "http": {
#         "commandName": "Project",
#         "dotnetRunMessages": true,
#         "launchBrowser": false,
#         "applicationUrl": "http://0.0.0.0:17000",
#         "environmentVariables": {
#           "ASPNETCORE_ENVIRONMENT": "Development",
#           "DOTNET_ENVIRONMENT": "Development",
#           "ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL": "http://localhost:17001",
#           "ASPIRE_RESOURCE_SERVICE_ENDPOINT_URL": "http://localhost:17003",
#           "ASPIRE_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS": "true",
#           "ASPIRE_ALLOW_UNSECURED_TRANSPORT": "true"
#         }
#       }
#     }
#   }
#   EOF
