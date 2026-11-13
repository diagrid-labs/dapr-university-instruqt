#!/usr/bin/env bash
# Warms caches inside the sandbox image: package caches (~/.nuget, ~/.m2, uv's cache) and the
# container images `dapr init` and the secrets labs pull. Runs after install-tools.sh in the
# Image Builder session. Never runs `dapr init` or starts a container: the Image Builder saves
# the state of running services into the image.
#
# Needs PREWARM_DAPR_RUNTIME_VERSION (rendered from versions.hcl). Failures to clone or pull are
# warnings: the sandbox still works, it is just slower on first use. A failing package build is
# fatal (set -e) on purpose, so a broken image is noticed while it is being built.

set -euo pipefail

: "${PREWARM_DAPR_RUNTIME_VERSION:?PREWARM_DAPR_RUNTIME_VERSION is not set}"

# Images that `dapr init` (Dapr 1.19) pulls: the runtime image also serves placement and
# scheduler, plus Redis and Zipkin. Vault is started by the secrets lab, RabbitMQ by the pubsub lab.
PREWARM_IMAGES=(
    "daprio/dapr:$PREWARM_DAPR_RUNTIME_VERSION"
    "redis:6"
    "openzipkin/zipkin"
    "hashicorp/vault:1.20"
    "rabbitmq:4.4.0-management"
)

# Container images, only if a Docker daemon is up.
if docker info >/dev/null 2>&1; then
    for image in "${PREWARM_IMAGES[@]}"; do
        docker pull "$image" || echo "WARNING: could not pull $image" >&2
    done
else
    echo "WARNING: Docker daemon is not reachable, skipping container image pre-pull." >&2
fi

# Package caches. Without this, the first `dapr run` of each language in the sandbox pays a full
# cold restore, which is minutes of a 30-minute lab. Only the caches are kept; the checkout
# itself is thrown away because lab setup clones the repo fresh at launch.
PREWARM_DIR="$(mktemp -d)"
trap 'rm -rf "$PREWARM_DIR"' EXIT
if git clone --depth 1 https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git "$PREWARM_DIR/repo"; then
    SECRETS_BASE="$PREWARM_DIR/repo/secrets"
    # The swap demo (demo 3) holds no application code (it runs the demo 1 app against another
    # secret store), so warming demo 1 and the two scoping apps covers all challenges. Folder
    # names follow each language: PascalCase for .NET, kebab-case for Python and Java.
    for demo in Demo1-ReadSecret Demo2-Scoping/AppA Demo2-Scoping/AppB; do
        (cd "$SECRETS_BASE/dotnet/$demo" && dotnet build)
    done
    for demo in demo1-read-secret demo2-scoping/app-a demo2-scoping/app-b; do
        (cd "$SECRETS_BASE/python/$demo" && uv sync)
        (cd "$SECRETS_BASE/java/$demo" && mvn -q -DskipTests package)
    done

    # Pubsub demos 1 to 5 (demo 6 swaps the broker and holds no code). Every app folder, in all
    # three languages: PascalCase for .NET, kebab-case for Python and Java.
    REPO_DIR="$PREWARM_DIR/repo"
    for app in \
        pubsub/dotnet/Demo1-Subscriptions/OrderApi \
        pubsub/dotnet/Demo1-Subscriptions/Shipping \
        pubsub/dotnet/Demo1-Subscriptions/Invoicing \
        pubsub/dotnet/Demo2-Streaming/OrderApi \
        pubsub/dotnet/Demo2-Streaming/Warehouse \
        pubsub/dotnet/Demo3-CloudEvents/OrderApi \
        pubsub/dotnet/Demo3-CloudEvents/Shipping \
        pubsub/dotnet/Demo4-Bulk/OrderApi \
        pubsub/dotnet/Demo4-Bulk/Shipping \
        pubsub/dotnet/Demo5-RoutingDeadLetter/OrderApi \
        pubsub/dotnet/Demo5-RoutingDeadLetter/Shipping; do
        (cd "$REPO_DIR/$app" && dotnet build)
    done
    for app in \
        pubsub/python/demo1-subscriptions/order-api \
        pubsub/python/demo1-subscriptions/shipping \
        pubsub/python/demo1-subscriptions/invoicing \
        pubsub/python/demo2-streaming/order-api \
        pubsub/python/demo2-streaming/warehouse \
        pubsub/python/demo3-cloud-events/order-api \
        pubsub/python/demo3-cloud-events/shipping \
        pubsub/python/demo4-bulk/order-api \
        pubsub/python/demo4-bulk/shipping \
        pubsub/python/demo5-routing-dead-letter/order-api \
        pubsub/python/demo5-routing-dead-letter/shipping; do
        (cd "$REPO_DIR/$app" && uv sync)
    done
    for app in \
        pubsub/java/demo1-subscriptions/order-api \
        pubsub/java/demo1-subscriptions/shipping \
        pubsub/java/demo1-subscriptions/invoicing \
        pubsub/java/demo2-streaming/order-api \
        pubsub/java/demo2-streaming/warehouse \
        pubsub/java/demo3-cloud-events/order-api \
        pubsub/java/demo3-cloud-events/shipping \
        pubsub/java/demo4-bulk/order-api \
        pubsub/java/demo4-bulk/shipping \
        pubsub/java/demo5-routing-dead-letter/order-api \
        pubsub/java/demo5-routing-dead-letter/shipping; do
        (cd "$REPO_DIR/$app" && mvn -q -DskipTests package)
    done
else
    echo "WARNING: could not clone the demo repo, so the package caches are cold. The sandbox" >&2
    echo "will still work, but the first build of each language will be slow." >&2
fi

