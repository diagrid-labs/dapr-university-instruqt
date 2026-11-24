#!/usr/bin/env bash
# Page 1 check: the Engineering project references the Dapr.Workflow package.
# Read-only. WORKSPACE overrides the lab's workspace folder (pytest and the drift suite set it).
set -u
WORKSPACE="${WORKSPACE:-/root/university-labs/workflow-aspire}"
file="$WORKSPACE/MeridianDiagnostics/Engineering/Engineering.csproj"
# A missing project is check-engineering.sh's to report, so the learner sees one hint, not two.
[ -f "$file" ] || exit 0
if ! grep -Eq '<PackageReference[[:space:]]+Include="Dapr\.Workflow"' "$file"; then
    echo "$file has no PackageReference to Dapr.Workflow."
    exit 1
fi
echo "Engineering.csproj references Dapr.Workflow."
