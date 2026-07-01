# The environment is prepared by _setup/sandbox-setup.sh (clone + dapr init) and
# the base image (Aspire CLI). This only fills in anything that isn't ready yet.

# Install the Aspire CLI if it isn't on the PATH.
if ! command -v aspire >/dev/null 2>&1; then
    curl -sSL https://aspire.dev/install.sh | /bin/bash
    source /root/.bashrc
fi

# Re-initialize Dapr if it isn't running yet.
if [ -z "$(docker ps -f "name=dapr_placement" -f "status=running" -q)" ]; then
    dapr init
fi
