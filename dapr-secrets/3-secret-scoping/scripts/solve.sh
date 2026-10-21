set -e
export PATH="$HOME/.local/bin:$PATH"
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-$HOME/ai-agent-tracks-instruqt}"
DEMO="Demo2-Scoping"

# 1. Switch scoping on for app-b: remove the "# " in front of configFilePath. This is the same
# edit the assignment asks for. Every language has its own dapr.yaml, and the sed does nothing
# when the line is already active.
for lang in dotnet python java; do
    sed -i 's/# configFilePath:/configFilePath:/' "$TRACKS_SRC_DIR/secrets/$lang/$DEMO/dapr.yaml"
done

# 2. Stop whatever the learner has running (in any language) so the ports are free again.
for lang in dotnet python java; do
    (cd "$TRACKS_SRC_DIR/secrets/$lang/$DEMO" && dapr stop -f . >/dev/null 2>&1) || true
done
for _ in $(seq 1 30); do
    curl -s -o /dev/null http://localhost:5003/ || break
    sleep 1
done

# 3. Start both apps again, in .NET, in the background. The check only needs the apps to answer
# on ports 5002 and 5003, so it does not matter which language the learner used.
cd "$TRACKS_SRC_DIR/secrets/dotnet/$DEMO"
nohup dapr run -f . >/tmp/dapr-secrets-demo2.log 2>&1 &

# 4. Wait until app-b answers a request that its sidecar allows.
for _ in $(seq 1 120); do
    if curl -s http://localhost:5003/secret/payments-api-key | grep -q pk-test-7f3a9; then
        echo "Restarted both apps in .NET with the Configuration applied to app-b (whichever language you used before)."
        exit 0
    fi
    sleep 2
done
echo "App B did not start within 4 minutes. See /tmp/dapr-secrets-demo2.log" >&2
exit 1
