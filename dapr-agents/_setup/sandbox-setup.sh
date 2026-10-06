git clone --depth 1 --branch v1.0.7 https://github.com/dapr/dapr-agents.git
curl -LsSf https://astral.sh/uv/install.sh | sh

# Provision the OpenAI API key from the OPENAI_API_KEY Instruqt sandbox secret into a
# secrets.json read by a Dapr local file secret store, and point the llm-provider
# conversation component at it, so the learner doesn't have to supply (or see) a key.
QS="$PWD/dapr-agents/quickstarts"
if [ -n "${OPENAI_API_KEY}" ]; then
    python3 -c 'import json, os; print(json.dumps({"openai-api-key": os.environ["OPENAI_API_KEY"]}))' \
        > "$QS/secrets.json"

    cat > "$QS/resources/local-secret-store.yaml" <<'EOF'
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: local-secret-store
spec:
  type: secretstores.local.file
  version: v1
  metadata:
  - name: secretsFile
    value: secrets.json
EOF

    cat > "$QS/resources/llm-provider.yaml" <<'EOF'
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: llm-provider
spec:
  type: conversation.openai
  version: v1
  metadata:
  - name: key
    secretKeyRef:
      name: openai-api-key
      key: openai-api-key
  - name: model
    value: gpt-4.1-mini
auth:
  secretStore: local-secret-store
EOF
fi

wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
docker login -u ${DockerUSER} -p ${DockerPAT}
dapr init
dapr -v

if [ -n "$(docker ps -f "name=dapr_placement" -f "status=running" -q )" ] && [ -n "$(docker ps -f "name=dapr_scheduler" -f "status=running" -q )" ] && [ -n "$(docker ps -f "name=dapr_redis" -f "status=running" -q )"  ] && [ -n "$(docker ps -f "name=dapr_zipkin" -f "status=running" -q )" ];
then
    echo "The Dapr containers are running! 👍"
else
    dapr uninstall
    dapr init
fi

wget -qO- https://astral.sh/uv/install.sh | sh
