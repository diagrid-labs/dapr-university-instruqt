#!/usr/bin/env bash
# Page 1 check: `aspire new` created the solution, so MeridianDiagnostics/apphost.cs exists.
# Read-only. WORKSPACE overrides the lab's workspace folder (pytest and the drift suite set it).
set -u
WORKSPACE="${WORKSPACE:-/root/university-labs/workflow-aspire}"
file="$WORKSPACE/MeridianDiagnostics/apphost.cs"
if [ ! -f "$file" ]; then
    echo "$file not found: the solution has not been created."
    exit 1
fi
echo "Found $file."
