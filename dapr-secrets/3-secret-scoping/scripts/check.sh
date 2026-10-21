TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-$HOME/ai-agent-tracks-instruqt}"

# Every language ships the same Configuration resource. One of them has to exist.
config_found=false
for lang in dotnet python java; do
    if [ -f "$TRACKS_SRC_DIR/secrets/$lang/Demo2-Scoping/resources/config-app-b.yaml" ]; then
        config_found=true
    fi
done

# curl prints the body, a space and the HTTP status (000 when nothing answers).
a_orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5002/secret/orderdb-password)
b_orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5003/secret/orderdb-password)
b_payments=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5003/secret/payments-api-key)

if [ "$config_found" != "true" ]; then
    fail-message "config-app-b.yaml is missing from the resources folder of Demo2-Scoping. Did the track setup finish?"
    exit 1
elif [ "${a_orderdb##* }" != "200" ]; then
    fail-message "App A cannot read orderdb-password (HTTP ${a_orderdb##* }). Is 'dapr run -f .' running in your Demo2-Scoping folder?"
    exit 1
elif [ "${b_orderdb##* }" = "000" ]; then
    fail-message "App B does not answer on port 5003. Is 'dapr run -f .' running in your Demo2-Scoping folder?"
    exit 1
elif [ "${b_orderdb##* }" = "200" ]; then
    fail-message "App B can still read orderdb-password. Did you remove the '# ' in front of configFilePath in dapr.yaml, and restart 'dapr run -f .' afterwards?"
    exit 1
elif [ "${b_orderdb##* }" != "403" ]; then
    fail-message "App B was refused with HTTP ${b_orderdb##* } instead of 403: ${b_orderdb}. Check the Dapr CLI window for errors."
    exit 1
elif [ "${b_payments##* }" != "200" ]; then
    fail-message "App B is refused payments-api-key as well (HTTP ${b_payments##* }). It is in allowedSecrets, so check config-app-b.yaml."
    exit 1
else
    echo "App A reads orderdb-password and App B is told no! 👍"
fi
