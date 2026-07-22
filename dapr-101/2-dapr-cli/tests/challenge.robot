# Robot Framework test suite. A .robot file is organized into *** sections ***.
# The single most important syntax rule: arguments are separated by TWO OR MORE
# spaces (a single space is part of the value). So `Some Keyword    arg1    arg2`
# is a keyword call with two arguments, but `dapr -h` is a single argument.

*** Settings ***
# Suite-level configuration. `Documentation` is free text describing the suite;
# `...` continues the previous line (used here so the doc can span two lines).
Documentation     Drift test for dapr-101 challenge 2 (Dapr CLI). Assumes the Dapr CLI is
...               already installed and `dapr init` has run (done by ci/setup-dapr-101.sh).
# `Resource` imports the custom keywords (Start Background Process, Run And Expect
# RC Zero, etc.) defined in the shared dapr.resource file.
Resource          ../../../tools/track-tester/resources/dapr.resource
# `Suite Teardown` runs once after all tests, even on failure. Terminate All
# Processes (from the Process library) kills anything left running.
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
# Scalar variables, referenced elsewhere as ${DAPR_VERSION}. Defined once here so
# the pinned version is easy to bump in a single place.
${DAPR_VERSION}    1.18.0
${DAPR_RUNTIME_VERSION}    1.18.0

*** Test Cases ***
# Each unindented line names a test case; indented lines are the steps it runs.
Dapr CLI Reports Help
    # Custom keyword from dapr.resource: run `dapr -h` and assert its output
    # contains the given text. First arg is the command, second is the expected text.
    Assert Command Output Contains    dapr -h    Distributed Application Runtime

Dapr Version Matches Pinned Runtime
    # `${r}=` captures the keyword's return value into a local variable.
    ${r}=    Run And Expect RC Zero    dapr --version
    # `${r.stdout}` reads the .stdout attribute of the returned result object.
    # `Should Contain` (from a built-in library) fails the test if the substring is absent.
    Should Contain    ${r.stdout}    CLI version: ${DAPR_VERSION}
    Should Contain    ${r.stdout}    Runtime version: ${DAPR_RUNTIME_VERSION}

Dapr Init Containers Are Running
    ${r}=    Run And Expect RC Zero    docker ps --format {{.Names}}
    Should Contain    ${r.stdout}    dapr_placement
    Should Contain    ${r.stdout}    dapr_scheduler
    Should Contain    ${r.stdout}    dapr_redis
    Should Contain    ${r.stdout}    dapr_zipkin

# doc-sync coverage (performed by ci/setup-dapr-101.sh, asserted above):
#   wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
#   dapr init
