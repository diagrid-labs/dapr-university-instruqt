# The three demos in this challenge all publish to the Redis Streams container
# that `dapr init` starts, so a running Dapr environment is what this checks.
if [ -z "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
    fail-message "The Redis message broker isn't running. Run 'dapr init' in the Dapr CLI window and try again."
elif [ -z "$(docker ps -f "name=dapr_placement" -f "status=running" -q)" ]; then
    fail-message "The Dapr placement service isn't running. Run 'dapr init' in the Dapr CLI window and try again."
elif [ ! -d "dapr-pub-sub-deep-dive/Demo1-Declarative" ]; then
    fail-message "The dapr-pub-sub-deep-dive repository is missing. Run 'git clone https://github.com/diagrid-labs/dapr-pub-sub-deep-dive.git' from your home directory."
else
    echo "Dapr and the demo code are ready! 👍"
fi
