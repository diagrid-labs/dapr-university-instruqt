# A .resource file holds reusable keywords (Robot Framework's equivalent of
# functions) that test suites import via `Resource    .../dapr.resource`. It has no
# *** Test Cases *** section — only *** Settings *** and *** Keywords ***.

*** Settings ***
# `Library` imports keywords from an external (Python) library. These three ship
# with Robot Framework: Process (start/stop processes), OperatingSystem (files),
# and Collections (list/dict helpers).
Library    Process
Library    OperatingSystem
Library    Collections

*** Keywords ***
# Each unindented name below defines a keyword. `[Arguments]` declares its
# parameters; `name=default` makes an argument optional. Keywords are called from
# suites (or other keywords) with 2+ spaces between the name and each argument.
Start Background Process
    # ${cwd}=${EMPTY} — optional working dir, defaulting to the built-in empty string.
    [Arguments]    ${command}    ${logfile}    ${alias}    ${cwd}=${EMPTY}
    # Truncate/create the log file so a stale one from a previous run can't be matched.
    Create File    ${logfile}    ${EMPTY}
    # Launch without blocking. shell=True runs via the shell; alias lets callers refer
    # to this process by name later; stderr=STDOUT merges both streams into the logfile.
    ${handle}=    Start Process    ${command}    shell=True    alias=${alias}
    ...    cwd=${cwd}    stdout=${logfile}    stderr=STDOUT
    # `RETURN` hands the process handle back to the caller.
    RETURN    ${handle}

Wait Until Log Contains
    [Arguments]    ${logfile}    ${text}    ${timeout}=60s
    # Retry the wrapped keyword (File Should Contain) every 2s until it passes or the
    # timeout elapses. This is how we poll a log for an expected line.
    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    File Should Contain    ${logfile}    ${text}

File Should Contain
    [Arguments]    ${logfile}    ${text}
    # Read the whole file, then assert the substring is present (fails otherwise).
    ${content}=    Get File    ${logfile}
    Should Contain    ${content}    ${text}

Stop Process With SIGINT
    [Arguments]    ${alias}    ${timeout}=15s
    # Referenced by the alias set in Start Background Process.
    # group=True signals the whole process group (like Ctrl+C), so the dapr CLI
    # AND its child daprd both receive SIGINT and shut down gracefully. Signaling
    # only the single PID leaves daprd unsignaled on Linux, so dapr never exits
    # (it worked on macOS but hung on the Linux CI runner). Robot starts processes
    # in their own session/group, so this targets only our process, not the runner.
    Send Signal To Process    SIGINT    ${alias}    group=True
    # Block until the process exits; if it overruns the timeout, do NOT rely on
    # Robot's built-in on_timeout=kill, since that only force-kills the single
    # tracked top-level PID (the `dapr run -f .` process), not its children.
    # daprd and the app process can survive that as orphans, still squatting the
    # fixed ports/app-id and corrupting the next test. Instead, wait without
    # killing, and if it's still not done, force-kill the whole tree.
    ${result}=    Wait For Process    ${alias}    timeout=${timeout}    on_timeout=continue
    IF    $result is None
        # SIGINT didn't stop the tree in time. `Send Signal To Process ... group=True`
        # is NOT enough here: `dapr run -f .` (and even the app process it launches)
        # each detach themselves into a NEW process group at startup, independent of
        # the tracked alias's own group - confirmed empirically (macOS): when the
        # tracked alias is itself a `bash -c '... && dapr run -f .'` wrapper (needed
        # to activate a venv before running dapr), `dapr run`, daprd and the app end
        # up in one or more process groups the wrapper's own group signal can never
        # reach, so they survive as orphans (reparented to init) even after a
        # group-targeted SIGKILL. The only reliable fallback is to walk the real
        # OS parent/child PID tree (not process groups) from the tracked PID, any
        # depth, and SIGKILL every descendant directly.
        ${pid}=    Get Process Id    ${alias}
        Run Process    bash    -c
        ...    kill_tree() { for c in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$c"; done; kill -9 "$1" 2>/dev/null; }; kill_tree ${pid}
        ${result}=    Wait For Process    ${alias}    timeout=10s    on_timeout=kill
    END
    RETURN    ${result}

Run And Expect RC Zero
    # Run a command to completion (blocking) and fail the test unless it exits 0.
    [Arguments]    ${command}    ${cwd}=${EMPTY}
    # stdout=PIPE captures output into the result object; stderr merges into it.
    ${result}=    Run Process    ${command}    shell=True    cwd=${cwd}
    ...    stdout=PIPE    stderr=STDOUT    timeout=300s
    # ${result.rc} is the exit code. `msg=` is the failure message shown if it's non-zero;
    # \n is a newline so the captured output prints on its own line.
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=Command failed (rc=${result.rc}): ${command}\n${result.stdout}
    RETURN    ${result}

Assert Command Output Contains
    # Convenience wrapper: run a command (expecting rc 0) AND assert its output contains text.
    [Arguments]    ${command}    ${text}    ${cwd}=${EMPTY}
    ${result}=    Run And Expect RC Zero    ${command}    ${cwd}
    Should Contain    ${result.stdout}    ${text}
    RETURN    ${result}

Run Multi-App And Assert Markers
    # ${markers} is a list; iterated below to confirm each expected line appears in the log.
    [Arguments]    ${run_command}    ${cwd}    ${logfile}    ${markers}    ${timeout}=180s
    # Start the multi-app `dapr run` in the background under the alias "apps".
    Start Background Process    ${run_command}    ${logfile}    apps    cwd=${cwd}
    # FOR loop over the list; @{markers} expands the list variable into its items.
    FOR    ${marker}    IN    @{markers}
        Wait Until Log Contains    ${logfile}    ${marker}    ${timeout}
    END
    # `END` closes the FOR block. Once all markers are seen, shut the apps down.
    Stop Process With SIGINT    apps

Assert Redis Keys Contain
    # Run `redis-cli KEYS *` inside the Dapr Redis container and assert ${key} is listed.
    [Arguments]    ${key}
    Assert Command Output Contains    docker exec dapr_redis redis-cli KEYS '*'    ${key}
