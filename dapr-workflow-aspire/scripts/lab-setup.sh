# shellcheck shell=bash
# Lab-specific setup for dapr-workflow-aspire. The dapr-sandbox module builds the VM startup script as
# `( export <inputs>; source /usr/local/lib/dapr-sandbox/sandbox-setup.sh; <this lab script> )`
# under `set -euo pipefail`, and writes the ready marker itself once the subshell succeeds. So the
# module's shared setup has already run when this file starts: Docker is up, DNS and outbound HTTPS
# work, the demo repo is cloned at the pinned ref, the Editor and Dev Dashboard run, and
# `dapr init` is done. Available here: the functions `log`, `die`, `bounded`, `wait_for_docker`
# and the variables HOME, TRACKS_SRC_DIR, LAB_SETUP_LOG. -e/-u/pipefail are inherited, `exit` only
# leaves the subshell, and nothing here may touch the marker. LAB_ASPIRE_CLI_VERSION comes from the
# module's lab_environment input (versions.hcl), so the pin lives in one file. (Not
# ASPIRE_CLI_VERSION: the Aspire CLI reads that name as an identity override.)
#
# The learner builds the app from scratch in $TRACKS_SRC_DIR/workflow-aspire, so this script never
# writes there. Its steps:
#   1. Stop the module's Dev Dashboard: the AppHost runs its own copy on port 9090 (page 3).
#   2. Install the Aspire CLI at the pin, on the default PATH of every terminal.
#   3. Warm up the CLI's template package and every NuGet package the pages use, in the background,
#      in a temp folder.
#   4. Opt out of the Aspire telemetry in every terminal.
# Safe to re-run.
: "${TRACKS_SRC_DIR:?TRACKS_SRC_DIR must be set (set by the module sandbox-setup.sh)}"
: "${LAB_ASPIRE_CLI_VERSION:?LAB_ASPIRE_CLI_VERSION must be set (lab_environment in dapr-workflow-aspire/versions.hcl)}"

if [ ! -d "$TRACKS_SRC_DIR/workflow-aspire" ]; then
    die "$TRACKS_SRC_DIR/workflow-aspire not found. Is $TRACKS_SRC_DIR a current clone of diagrid-labs/university-labs?"
fi

# 1. The module runs the Dev Dashboard as the systemd unit dev-dashboard-lab on port 9090. Page 3's
# AppHost starts the Dev Dashboard as an Aspire resource on the same port, so stop the module's copy.
# The Dev Dashboard tab stays empty until `aspire run`; the pages say so. A missing unit is fine.
systemctl stop dev-dashboard-lab >/dev/null 2>&1 || true
log "stopped the module's Dev Dashboard (dev-dashboard-lab); Aspire runs its own on port 9090"

# 2. The Aspire CLI at the pin. The installer puts the CLI and its files in one folder; a symlink in
# /usr/local/bin puts it on the default PATH of every terminal (--skip-path: no profile edits).
# The LAB_* overrides exist for the pytest in tools/track-tester/ci/tests.
ASPIRE_INSTALL_DIR="${LAB_ASPIRE_INSTALL_DIR:-/usr/local/lib/aspire}"
ASPIRE_BIN_DIR="${LAB_ASPIRE_BIN_DIR:-/usr/local/bin}"
# This is the CLI's first run on the VM, before step 4's profile exists: opt out of telemetry here,
# and read the version from anywhere in the output, so a first-run notice cannot fail the boot.
export ASPIRE_CLI_TELEMETRY_OPTOUT=true
aspire_version() { # the installed CLI's version (x.y.z, without the +<commit> suffix), or nothing
    { "$ASPIRE_BIN_DIR/aspire" --version 2>/dev/null | grep -Eom1 '[0-9]+\.[0-9]+\.[0-9]+'; } || true
}
if [ "$(aspire_version)" != "$LAB_ASPIRE_CLI_VERSION" ]; then
    installer="$(mktemp)"
    bounded 60 curl -fsSL https://aspire.dev/install.sh -o "$installer" ||
        die "could not download the Aspire CLI installer (https://aspire.dev/install.sh)"
    bounded 300 bash "$installer" --install-path "$ASPIRE_INSTALL_DIR" \
        --version "$LAB_ASPIRE_CLI_VERSION" --skip-path ||
        die "the Aspire CLI installer failed for version $LAB_ASPIRE_CLI_VERSION"
    rm -f "$installer"
    ln -sf "$ASPIRE_INSTALL_DIR/aspire" "$ASPIRE_BIN_DIR/aspire"
fi
[ -x "$ASPIRE_BIN_DIR/aspire" ] || die "the Aspire CLI is not at $ASPIRE_BIN_DIR/aspire after the install"
installed="$(aspire_version)"
[ "$installed" = "$LAB_ASPIRE_CLI_VERSION" ] ||
    die "the Aspire CLI is version '$installed', but the lab pins $LAB_ASPIRE_CLI_VERSION"
log "Aspire CLI $installed installed ($ASPIRE_BIN_DIR/aspire)"

# 3. Warm-up in a fully detached background job (own stdin, stdout and stderr), so the sandbox
# reports ready without waiting: the page commands, in a temp folder that is removed afterwards,
# so the CLI's template package and every NuGet package (Dapr.Workflow, the three `#:package` lines
# of the final apphost.cs) are cached before the learner needs them. The package versions mirror
# the pages. A failed step is logged and never fails the lab; the workspace is never touched.
# Progress: `tail -f /var/log/lab-prebuild.log`.
PREBUILD_LOG="${LAB_PREBUILD_LOG:-/var/log/lab-prebuild.log}"
touch "$PREBUILD_LOG" 2>/dev/null || PREBUILD_LOG=/dev/null
nohup bash -s -- "$ASPIRE_BIN_DIR/aspire" "$LAB_ASPIRE_CLI_VERSION" >>"$PREBUILD_LOG" 2>&1 <<'PREBUILD' &
aspire="$1"
version="$2"
export ASPIRE_CLI_TELEMETRY_OPTOUT=true DOTNET_CLI_TELEMETRY_OPTOUT=true DOTNET_NOLOGO=true
step() { # step <command...>: run in the temp folder, log a failure, carry on
    echo "$(date -u +%H:%M:%S) == $*"
    "$@" </dev/null || echo "WARN: warm-up step failed: $*"
}
tmp="$(mktemp -d "${TMPDIR:-/tmp}/aspire-warmup.XXXXXX")"
cd "$tmp" || exit 0
step "$aspire" new aspire-empty --version "$version" --name MeridianDiagnostics \
    --output MeridianDiagnostics --non-interactive --agents none --nologo
step dotnet new web -n Engineering -o MeridianDiagnostics/Engineering
step dotnet add MeridianDiagnostics/Engineering package Dapr.Workflow --version 1.19.1
mkdir -p MeridianDiagnostics
cat >MeridianDiagnostics/apphost.cs <<APPHOST
#:package Aspire.Hosting.AppHost@$version
#:package Aspire.Hosting.Dotnet@$version
#:package CommunityToolkit.Aspire.Hosting.Dapr@13.0.0

var builder = DistributedApplication.CreateBuilder(args);
builder.Build().Run();
APPHOST
(cd MeridianDiagnostics && step "$aspire" restore)
step dotnet build MeridianDiagnostics/Engineering
cd / && rm -rf "$tmp"
echo "$(date -u +%H:%M:%S) == warm-up done"
PREBUILD
log "Aspire warm-up started in the background (/var/log/lab-prebuild.log)"

# 4. Aspire telemetry off in every terminal. The lab terminals are interactive non-login shells,
# which read /etc/bash.bashrc and not /etc/profile.d, so bash.bashrc sources the profile file (once,
# however often this runs).
ASPIRE_PROFILE="${LAB_ASPIRE_PROFILE:-/etc/profile.d/aspire-lab.sh}"
BASHRC="${LAB_BASHRC:-/etc/bash.bashrc}"
mkdir -p "$(dirname "$ASPIRE_PROFILE")"
cat >"$ASPIRE_PROFILE" <<'PROFILE'
# Written by the dapr-workflow-aspire lab setup.
export ASPIRE_CLI_TELEMETRY_OPTOUT=true
export ASPIRE_DASHBOARD_TELEMETRY_OPTOUT=true
export DOTNET_CLI_TELEMETRY_OPTOUT=true
PROFILE
if ! grep -qF "$ASPIRE_PROFILE" "$BASHRC" 2>/dev/null; then
    printf '[ -r %s ] && . %s\n' "$ASPIRE_PROFILE" "$ASPIRE_PROFILE" >>"$BASHRC"
fi
log "Aspire telemetry opt-out written to $ASPIRE_PROFILE"
log "done after ${SECONDS}s"
