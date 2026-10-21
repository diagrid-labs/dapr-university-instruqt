set -e
export PATH="$HOME/.local/bin:$PATH"
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-$HOME/ai-agent-tracks-instruqt}"
DEMO="Demo3-SwapProvider"

# 1. Stop whatever the learner has running (any language, either folder) so the ports are free.
# Both folders start the same app from the same place, so both are stopped.
for lang in dotnet python java; do
    for folder in Demo1-ReadSecret "$DEMO"; do
        (cd "$TRACKS_SRC_DIR/secrets/$lang/$folder" && dapr stop -f . >/dev/null 2>&1) || true
    done
done
for _ in $(seq 1 30); do
    curl -s -o /dev/null http://localhost:5001/ || break
    sleep 1
done

# 2. Start the app against Vault: the same Demo1-ReadSecret, started from the swap folder. The
# check only needs port 5001 and the metadata endpoint of port 3500, so the language is not
# important.
cd "$TRACKS_SRC_DIR/secrets/dotnet/$DEMO"
nohup dapr run -f . >/tmp/dapr-secrets-demo3.log 2>&1 &

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
