# The environment is prepared by _setup/sandbox-setup.sh (clone + dapr init) and
# the base image (.NET 10 SDK, Dapr CLI). This only fills in what isn't ready yet.

# Re-clone the demo source if it's missing.
if [ ! -d "dapr-pub-sub-deep-dive" ]; then
    git clone https://github.com/diagrid-labs/dapr-pub-sub-deep-dive.git
fi

# Re-initialize Dapr if it isn't running yet.
if [ -z "$(docker ps -f "name=dapr_placement" -f "status=running" -q)" ]; then
    dapr init
fi
