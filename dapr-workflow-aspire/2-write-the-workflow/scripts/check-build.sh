#!/usr/bin/env bash
# Page 2 check: the Engineering project builds.
# Read-only: it builds without restoring into a temporary folder that it removes afterwards, so
# Engineering/bin stays as it is, also while `aspire run` runs the app.
# A missing project or paste is reported by its own check, so this one then passes and the learner
# sees one hint, not two.
# WORKSPACE overrides the lab's workspace folder (pytest and the drift suite set it).
set -u
WORKSPACE="${WORKSPACE:-/root/university-labs/workflow-aspire}"
solution="$WORKSPACE/MeridianDiagnostics"
eng="$solution/Engineering"
[ -f "$eng/Engineering.csproj" ] || exit 0
[ -f "$eng/Program.cs" ] || exit 0
grep -q 'class DiagnosticsWorkflow' "$eng/DiagnosticsWorkflow.cs" 2>/dev/null || exit 0
for class in DiagnoseSubsystemActivity PrioritizeDiagnosticsActivity NotifyBridgeActivity; do
    grep -q "class $class" "$eng/Activities.cs" 2>/dev/null || exit 0
done

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
if ! log="$(cd "$solution" && dotnet build Engineering --no-restore -o "$out" 2>&1)"; then
    echo "The Engineering project does not build."
    files="$(printf '%s\n' "$log" | grep -oE '[^/[:space:]]+\.cs\([0-9]+,[0-9]+\): error' | sed 's/(.*//' | sort -u | tr '\n' ' ')"
    [ -n "$files" ] && echo "Errors in: ${files% }"
    printf '%s\n' "$log" | grep -E ': error ' | sort -u | head -n 10
    exit 1
fi
echo "The Engineering project builds."
