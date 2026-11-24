#!/usr/bin/env bash
# Page 1 check: apphost.run.json binds the Aspire dashboard to http://0.0.0.0:17000, so the Aspire tab
# can reach it from outside the VM.
# Read-only. WORKSPACE overrides the lab's workspace folder (pytest and the drift suite set it).
set -u
WORKSPACE="${WORKSPACE:-/root/university-labs/workflow-aspire}"
file="$WORKSPACE/MeridianDiagnostics/apphost.run.json"
if [ ! -f "$file" ]; then
    echo "$file not found."
    exit 1
fi
if ! grep -Eq '"applicationUrl"[[:space:]]*:[[:space:]]*"http://0\.0\.0\.0:17000"' "$file"; then
    echo "$file does not bind the Aspire dashboard to http://0.0.0.0:17000."
    exit 1
fi
echo "apphost.run.json binds the Aspire dashboard to http://0.0.0.0:17000."
