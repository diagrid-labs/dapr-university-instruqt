#!/usr/bin/env bash
# Page 2 check: Program.cs registers the workflow (the heredoc replaced the template's Program.cs).
# Read-only. WORKSPACE overrides the lab's workspace folder (pytest and the drift suite set it).
set -u
WORKSPACE="${WORKSPACE:-/root/university-labs/workflow-aspire}"
file="$WORKSPACE/MeridianDiagnostics/Engineering/Program.cs"
if [ ! -f "$file" ]; then
    echo "$file not found."
    exit 1
fi
if ! grep -q 'AddDaprWorkflow' "$file"; then
    echo "$file does not call AddDaprWorkflow: it is still the Program.cs that dotnet new web created."
    exit 1
fi
echo "Program.cs registers the workflow."
