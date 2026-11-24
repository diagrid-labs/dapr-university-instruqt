#!/usr/bin/env bash
# Page 2 check: DiagnosticsWorkflow.cs is in the Engineering project and holds the pasted workflow.
# Read-only. WORKSPACE overrides the lab's workspace folder (pytest and the drift suite set it).
set -u
WORKSPACE="${WORKSPACE:-/root/university-labs/workflow-aspire}"
file="$WORKSPACE/MeridianDiagnostics/Engineering/DiagnosticsWorkflow.cs"
if [ ! -f "$file" ]; then
    echo "$file not found."
    exit 1
fi
if ! grep -q 'class DiagnosticsWorkflow' "$file"; then
    echo "$file has no 'class DiagnosticsWorkflow': the workflow code is not pasted into it."
    exit 1
fi
echo "DiagnosticsWorkflow.cs holds the DiagnosticsWorkflow class."
