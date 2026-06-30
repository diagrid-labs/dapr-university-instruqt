# The environment is prepared by _setup/sandbox-setup.sh (clone + dapr init).
# This only re-initializes Dapr if it isn't running yet.
if [ -z "$(docker ps -f "name=dapr_placement" -f "status=running" -q)" ]; then
    dapr init
fi
