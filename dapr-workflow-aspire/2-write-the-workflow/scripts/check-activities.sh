#!/usr/bin/env bash
# Page 2 check: Activities.cs is in the Engineering project and holds the three pasted activities.
# Read-only. WORKSPACE overrides the lab's workspace folder (pytest and the drift suite set it).
set -u
WORKSPACE="${WORKSPACE:-/root/university-labs/workflow-aspire}"
file="$WORKSPACE/MeridianDiagnostics/Engineering/Activities.cs"
if [ ! -f "$file" ]; then
    echo "$file not found."
    exit 1
fi
missing=""
for class in DiagnoseSubsystemActivity PrioritizeDiagnosticsActivity NotifyBridgeActivity; do
    grep -q "class $class" "$file" || missing="$missing $class"
done
if [ -n "$missing" ]; then
    echo "$file is missing these activity classes:$missing"
    exit 1
fi
echo "Activities.cs holds the three activities."
