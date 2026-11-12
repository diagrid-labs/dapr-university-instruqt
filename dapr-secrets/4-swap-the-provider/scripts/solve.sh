#!/usr/bin/env bash
set -e
export PATH="${HOME:-/root}/.local/bin:$PATH:/usr/local/bin"
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-${HOME:-/root}/ai-agent-tracks-instruqt}"

# 1. Stop whatever the learner has running (any language) so the ports are free. Demo 1 and the
# swap folder start the same app from the same place, so both are stopped; the scoping demo's apps
# may still be running from the previous page, because a 2.0 lab keeps them across pages. Folder
# names are PascalCase in .NET and kebab-case in Python and Java.
for folder in \
    dotnet/Demo1-ReadSecret dotnet/Demo2-Scoping dotnet/Demo3-SwapProvider \
    python/demo1-read-secret python/demo2-scoping python/demo3-swap-provider \
    java/demo1-read-secret java/demo2-scoping java/demo3-swap-provider; do
    (cd "$TRACKS_SRC_DIR/secrets/$folder" && dapr stop -f . >/dev/null 2>&1) || true
done
for _ in $(seq 1 30); do
    curl -s -o /dev/null http://localhost:5001/ || break
    sleep 1
done

# 2. Start the app against Vault: the same demo 1 app, started from the swap folder. The
# check only needs port 5001 and the metadata endpoint of port 3500, so the language is not
# important.
cd "$TRACKS_SRC_DIR/secrets/dotnet/Demo3-SwapProvider"
setsid nohup dapr run -f . </dev/null >/tmp/dapr-secrets-demo3.log 2>&1 &

# 3. Wait until the app answers a request that only works once the sidecar is ready.
for _ in $(seq 1 120); do
    if curl -s http://localhost:5001/secret/orderdb-password | grep -q s3cr3t-pa55w0rd; then
        echo "Restarted the app in .NET against Vault (whichever language you used before)."
        exit 0
    fi
    sleep 2
done
echo "The app did not start within 4 minutes. See /tmp/dapr-secrets-demo3.log" >&2
exit 1
