#!/usr/bin/env bash
set -u
export PATH="${HOME:-/root}/.local/bin:$PATH:/usr/local/bin"

# The first condition of the page, and not gated: the broker has to be there before the apps are
# started, so a learner who skipped step 1 gets this message first.
running=$(docker ps --filter "name=^rabbitmq$" --format '{{.Names}}' 2>/dev/null | grep -x rabbitmq || true)
if [ -z "$running" ]; then
    echo "The container 'rabbitmq' is not running. Start RabbitMQ with the Run block in step 1 first, then start the apps (press Ctrl+C in the Dapr CLI window and run 'dapr run -f .' again if they are already running)."
    exit 1
fi
echo "The container 'rabbitmq' is running."
