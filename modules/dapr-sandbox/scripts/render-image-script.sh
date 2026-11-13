#!/usr/bin/env bash
# Prints the self-contained script to paste into an Instruqt Image Builder session terminal.
# It exports the toolchain pins from versions.hcl, inlines install-tools.sh and prewarm.sh, then
# installs sandbox-setup.sh to /usr/local/lib/dapr-sandbox/.
#
#   modules/dapr-sandbox/scripts/render-image-script.sh > image.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(dirname "$HERE")"
READ_PIN="$MODULE_DIR/../../tools/track-tester/ci/read_pin.py"
VERSIONS="$MODULE_DIR/versions.hcl"

pin() {
    python3 "$READ_PIN" "$VERSIONS" "$1"
}

# Read everything before printing so a bad pin fails before any partial output.
dotnet_sdk_channel="$(pin dotnet_sdk_channel)"
java_version="$(pin java_version)"
node_major="$(pin node_major)"
dapr_cli_version="$(pin dapr_cli_version)"
code_server_version="$(pin code_server_version)"
dev_dashboard_version="$(pin dev_dashboard_version)"
runtime_version="$(pin prewarm_dapr_runtime_version)"

echo '#!/usr/bin/env bash'
echo 'set -euo pipefail'
echo
echo "export DOTNET_SDK_CHANNEL=$dotnet_sdk_channel"
echo "export JAVA_VERSION=$java_version"
echo "export NODE_MAJOR=$node_major"
echo "export DAPR_CLI_VERSION=$dapr_cli_version"
echo "export CODE_SERVER_VERSION=$code_server_version"
echo "export DEV_DASHBOARD_VERSION=$dev_dashboard_version"
echo "export PREWARM_DAPR_RUNTIME_VERSION=$runtime_version"

# Inline the script bodies without their shebang line.
for script in install-tools.sh prewarm.sh; do
    echo
    echo "# ---- $script ----"
    tail -n +2 "$HERE/$script"
done

# Ship sandbox-setup.sh in the image: the module's startup script sources it at boot, before the
# lab's own script. The heredoc is quoted, so the content is written verbatim.
echo
echo "# ---- install sandbox-setup.sh ----"
echo "mkdir -p /usr/local/lib/dapr-sandbox"
echo "cat > /usr/local/lib/dapr-sandbox/sandbox-setup.sh <<'SANDBOX_SETUP_EOF'"
cat "$HERE/sandbox-setup.sh"
echo "SANDBOX_SETUP_EOF"
echo "chmod 0755 /usr/local/lib/dapr-sandbox/sandbox-setup.sh"
