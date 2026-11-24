#!/usr/bin/env bash
# Page 1 check: `dotnet new web` created the Engineering project in the solution.
# Read-only. WORKSPACE overrides the lab's workspace folder (pytest and the drift suite set it).
set -u
WORKSPACE="${WORKSPACE:-/root/university-labs/workflow-aspire}"
file="$WORKSPACE/MeridianDiagnostics/Engineering/Engineering.csproj"
if [ ! -f "$file" ]; then
    echo "$file not found: the Engineering project has not been created."
    exit 1
fi
echo "Found $file."
