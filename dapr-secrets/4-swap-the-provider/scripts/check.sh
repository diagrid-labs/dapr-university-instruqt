# curl prints the body, a space and the HTTP status (000 when nothing answers).
orderdb=$(curl -s -m 10 -w ' %{http_code}' http://localhost:5001/secret/orderdb-password)
# The sidecar lists every loaded component and its type. This is the line for `secretstore`.
store=$(curl -s -m 10 http://localhost:3500/v1.0/metadata | grep -o '"name":"secretstore","type":"[^"]*"' || true)

if [ "${orderdb##* }" = "000" ]; then
    fail-message "The app does not answer on port 5001. Is 'dapr run -f .' running in your Demo3-SwapProvider folder?"
    exit 1
elif [ "$store" != '"name":"secretstore","type":"secretstores.hashicorp.vault"' ]; then
    fail-message "The app isn't reading from Vault yet — is secretstore-vault.yaml the component Dapr loaded? Stop the running app with Ctrl+C and start it with 'dapr run -f .' from the Demo3-SwapProvider folder, not from Demo1-ReadSecret."
    exit 1
elif [ "${orderdb##* }" != "200" ]; then
    fail-message "Dapr loaded the Vault component, but the app cannot read orderdb-password (HTTP ${orderdb##* }): ${orderdb}. Is Vault running ('docker ps') and does it hold the secrets? Check the Dapr CLI window for errors."
    exit 1
else
    echo "The app reads orderdb-password from Vault, and nobody touched its code! 👍"
fi
