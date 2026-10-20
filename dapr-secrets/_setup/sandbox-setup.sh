set -euo pipefail

# The demo repo holds the three-language apps and the scoping/Vault resources. It lives at a
# fixed path because the track-tester suites and the assignments both refer to it.
TRACKS_SRC_DIR="$HOME/ai-agent-tracks-instruqt"
if [ ! -d "$TRACKS_SRC_DIR/.git" ]; then
    git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git "$TRACKS_SRC_DIR"
fi

docker login -u ${DockerUSER} -p ${DockerPAT}

# Keep these two lines plain `agent variable set NAME VALUE`: ci/setup-dapr-secrets.sh parses the
# version out of them with awk, so the version lives in exactly one place.
agent variable set DAPR_CLI_VERSION 1.18.2
agent variable set DAPR_RUNTIME_VERSION 1.18.7

if ! command -v dapr >/dev/null 2>&1; then
    wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
fi
dapr -v

# `dapr init` is skipped when the containers are already running, so re-running this script on a
# relaunched sandbox does not tear down and re-create them.
dapr_containers_running() {
    [ -n "$(docker ps -f "name=dapr_placement" -f "status=running" -q )" ] && \
    [ -n "$(docker ps -f "name=dapr_scheduler" -f "status=running" -q )" ] && \
    [ -n "$(docker ps -f "name=dapr_redis" -f "status=running" -q )" ]
}
if dapr_containers_running; then
    echo "The Dapr containers are running! 👍"
else
    dapr init
    if ! dapr_containers_running; then
        dapr uninstall
        dapr init
    fi
fi

wget -qO- https://astral.sh/uv/install.sh | sh

# BEGIN ci-shared: secrets.json and Vault (extracted and run by ci/setup-dapr-secrets.sh)
# secrets.json is generated here and nowhere else; the committed secrets.example.json in the demo
# repo is only a template. The redirect truncates, so a re-run leaves identical bytes.
mkdir -p "${TRACKS_SRC_DIR:?}/secrets"
printf '{\n  "orderdb-password": "s3cr3t-pa55w0rd",\n  "payments-api-key": "pk-test-7f3a9"\n}\n' \
    > "${TRACKS_SRC_DIR:?}/secrets/secrets.json"

# Vault in dev mode (in-memory, root token "root") holds the same two secrets for challenge 4.
# Dev mode keeps nothing across restarts, so removing any existing container first and re-seeding
# gives the same state on every run.
docker rm -f vault >/dev/null 2>&1 || true
docker run -d --name vault -p 8200:8200 --cap-add=IPC_LOCK \
    -e VAULT_DEV_ROOT_TOKEN_ID=root -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
    hashicorp/vault:1.20 >/dev/null
for _ in $(seq 1 30); do
    docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault vault status >/dev/null 2>&1 && break
    sleep 1
done
# Dapr's Vault store reads secret/dapr/<name> (KV v2, default prefix "dapr").
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=root vault \
    vault kv put secret/dapr/orderdb-password orderdb-password=s3cr3t-pa55w0rd >/dev/null
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=root vault \
    vault kv put secret/dapr/payments-api-key payments-api-key=pk-test-7f3a9 >/dev/null
# END ci-shared

# Pre-build Demo1-ReadSecret so the first `dapr run` isn't slow. The demo apps are added by the
# challenge 1 task, so a missing directory is a no-op rather than a failure.
SECRETS_BASE="$TRACKS_SRC_DIR/secrets"
if [ -d "$SECRETS_BASE/dotnet/Demo1-ReadSecret" ]; then
    (cd "$SECRETS_BASE/dotnet/Demo1-ReadSecret" && dotnet build)
fi
if [ -d "$SECRETS_BASE/python/Demo1-ReadSecret" ]; then
    (cd "$SECRETS_BASE/python/Demo1-ReadSecret" && uv sync)
fi
if [ -d "$SECRETS_BASE/java/Demo1-ReadSecret" ]; then
    (cd "$SECRETS_BASE/java/Demo1-ReadSecret" && mvn -q -DskipTests package)
fi
