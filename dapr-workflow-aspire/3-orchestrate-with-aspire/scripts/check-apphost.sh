#!/usr/bin/env bash
# Page 3 check: apphost.cs describes the app: the Dapr integration package, the statestore component,
# the engineering project with its Dapr sidecar and the dev-dashboard executable.
# Read-only. WORKSPACE overrides the lab's workspace folder (pytest and the drift suite set it).
set -u
WORKSPACE="${WORKSPACE:-/root/university-labs/workflow-aspire}"
file="$WORKSPACE/MeridianDiagnostics/apphost.cs"
if [ ! -f "$file" ]; then
    echo "$file not found."
    exit 1
fi
missing=""
grep -q '^#:package CommunityToolkit\.Aspire\.Hosting\.Dapr@' "$file" || missing="$missing
- the CommunityToolkit.Aspire.Hosting.Dapr package"
grep -q 'AddDaprComponent("statestore"' "$file" || missing="$missing
- the statestore component (AddDaprComponent)"
grep -q 'AddDotnetProject("engineering"' "$file" || missing="$missing
- the engineering project (AddDotnetProject)"
grep -q 'WithDaprSidecar' "$file" || missing="$missing
- the Dapr sidecar of the engineering project (WithDaprSidecar)"
grep -q 'AddExecutable("dev-dashboard"' "$file" || missing="$missing
- the dev-dashboard executable (AddExecutable)"
if [ -n "$missing" ]; then
    echo "$file is missing:$missing"
    exit 1
fi
echo "apphost.cs describes the statestore, engineering and dev-dashboard resources."
