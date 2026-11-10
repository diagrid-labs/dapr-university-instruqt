# shellcheck shell=bash
# Library: defines seed_vault and nothing else, so it can be sourced (lab-setup.sh on the VM,
# ci/setup-dapr-secrets.sh and the challenge 4 Robot test). Callers own `set -euo pipefail`.
#
# seed_vault <secrets.json>
#   Starts HashiCorp Vault in dev mode (in-memory, root token "root", port 8200), waits up to
#   30 seconds for it and writes every name/value of the JSON file to secret/dapr/<name>.
#   Dev mode keeps nothing across restarts, so removing any existing container first and
#   re-seeding gives the same state on every run.
seed_vault() {
    local secrets_json="$1"
    docker rm -f vault >/dev/null 2>&1 || true
    docker run -d --name vault -p 8200:8200 --cap-add=IPC_LOCK \
        -e VAULT_DEV_ROOT_TOKEN_ID=root -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
        hashicorp/vault:1.20 >/dev/null
    local vault_ready=false
    local _
    for _ in $(seq 1 30); do
        if docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault vault status >/dev/null 2>&1; then
            vault_ready=true
            break
        fi
        sleep 1
    done
    if [ "$vault_ready" != "true" ]; then
        echo "ERROR: Vault did not become ready within 30 seconds." >&2
        return 1
    fi
    # Dapr's Vault store reads secret/dapr/<name> (KV v2, default prefix "dapr").
    # Note: `read -r name value` trims leading/trailing whitespace in a value; fine for these values.
    python3 -c 'import json, sys; [print(k, v) for k, v in json.load(open(sys.argv[1])).items()]' \
        "$secrets_json" | tr -d '\r' | while read -r name value; do
        docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=root vault \
            vault kv put "secret/dapr/$name" "$name=$value" >/dev/null </dev/null
    done
}
