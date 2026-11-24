"""dapr-workflow-aspire/scripts/lab-setup.sh is the lab's whole startup script: the module inlines
it after its shared setup, in one strict-mode subshell, with ASPIRE_CLI_VERSION from the module's
lab_environment input (LAB_ASPIRE_CLI_VERSION). It stops the module's Dev Dashboard (Aspire runs its own on 9090), installs
the Aspire CLI at the pin, starts a background warm-up in a temp folder, and opts out of telemetry.

`systemctl`, `curl` (which "downloads" a fake installer), the installed `aspire` and `dotnet` are
stubs that log their calls, so the test runs anywhere without root."""
import os
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
LAB = ROOT / "dapr-workflow-aspire"
SETUP = LAB / "scripts" / "lab-setup.sh"
PIN = "17.0.0"
HELPERS = 'log() { echo "log: $*"; }\ndie() { echo "$*" >&2; exit 1; }\nbounded() { shift; "$@"; }\n'

# The fake installer: logs its arguments and, unless told not to, puts an `aspire` stub in
# --install-path that answers `--version` and logs every other call with its working folder.
INSTALLER = r'''#!/usr/bin/env bash
echo "$*" >> "$STUB_LOG_DIR/install.log"
dir=""
while [ $# -gt 0 ]; do
    case "$1" in --install-path) dir="$2"; shift ;; esac
    shift
done
[ -n "${STUB_INSTALL_NOTHING:-}" ] && exit 0
mkdir -p "$dir"
cat > "$dir/aspire" <<'ASPIRE'
#!/usr/bin/env bash
if [ "$1" = "--version" ]; then
    echo "telemetry_optout=${ASPIRE_CLI_TELEMETRY_OPTOUT:-}" >> "$STUB_LOG_DIR/aspire-version.log"
    # A first run can print a notice (welcome, telemetry) on stdout before the version.
    [ -n "${STUB_ASPIRE_NOTICE:-}" ] && echo "$STUB_ASPIRE_NOTICE"
    echo "${STUB_ASPIRE_VERSION}+2d325b13709752ba6d9a943635c5e2940a2530c0"; exit 0
fi
echo "$PWD | $*" >> "$STUB_LOG_DIR/aspire.log"
# The Aspire CLI reads ASPIRE_CLI_VERSION as an identity override ("emulating identity").
[ -n "${ASPIRE_CLI_VERSION:-}" ] && echo "ASPIRE_CLI_VERSION=$ASPIRE_CLI_VERSION" >> "$STUB_LOG_DIR/aspire-env.log"
if [ "$1" = "new" ]; then
    while [ $# -gt 0 ]; do
        case "$1" in --output) mkdir -p "$2"; touch "$2/apphost.cs"; shift ;; esac
        shift
    done
fi
exit 0
ASPIRE
chmod +x "$dir/aspire"
'''


def _stubs(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    (tmp_path / "installer.sh").write_text(INSTALLER)
    (bin_dir / "systemctl").write_text(
        '#!/usr/bin/env bash\necho "$*" >> "$STUB_LOG_DIR/systemctl.log"\nexit 5\n')
    (bin_dir / "curl").write_text(
        '#!/usr/bin/env bash\necho "$*" >> "$STUB_LOG_DIR/curl.log"\nout=""\n'
        'while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; esac; shift; done\n'
        f'cp "{tmp_path}/installer.sh" "$out"\n')
    (bin_dir / "dotnet").write_text(
        '#!/usr/bin/env bash\necho "$PWD | $*" >> "$STUB_LOG_DIR/dotnet.log"\n'
        'if [ "$1" = "new" ]; then\n'
        '    while [ $# -gt 0 ]; do case "$1" in -o) mkdir -p "$2"; shift ;; esac; shift; done\n'
        'fi\nexit "${STUB_DOTNET_RC:-0}"\n')
    for f in bin_dir.iterdir():
        f.chmod(0o755)
    return bin_dir


def _env(tmp_path, prebuild_log="prebuild.log", **extra_env):
    # The developer's own opt-out must not hide whether the script sets it.
    inherited = {k: v for k, v in os.environ.items() if k != "ASPIRE_CLI_TELEMETRY_OPTOUT"}
    return {
        **inherited,
        "PATH": f"{tmp_path / 'bin'}:{os.environ['PATH']}",
        "TRACKS_SRC_DIR": str(tmp_path / "src"),
        "LAB_ASPIRE_CLI_VERSION": PIN,
        "STUB_ASPIRE_VERSION": PIN,
        "STUB_LOG_DIR": str(tmp_path / "logs"),
        "TMPDIR": str(tmp_path / "tmp"),
        "LAB_PREBUILD_LOG": str(tmp_path / prebuild_log),
        "LAB_ASPIRE_INSTALL_DIR": str(tmp_path / "lib" / "aspire"),
        "LAB_ASPIRE_BIN_DIR": str(tmp_path / "usr-local-bin"),
        "LAB_ASPIRE_PROFILE": str(tmp_path / "profile.d" / "aspire-lab.sh"),
        "LAB_BASHRC": str(tmp_path / "bash.bashrc"),
        **extra_env,
    }


def _run(tmp_path, **extra_env):
    _stubs(tmp_path)
    ws = tmp_path / "src" / "workflow-aspire"
    ws.mkdir(parents=True)
    (ws / "README.md").write_text("workspace\n")
    for d in ("logs", "tmp", "usr-local-bin"):
        (tmp_path / d).mkdir()
    script = tmp_path / "startup.sh"
    script.write_text(f"set -euo pipefail\n(\n{HELPERS}{SETUP.read_text()}\n)\n")
    r = subprocess.run(["bash", str(script)], capture_output=True, text=True,
                       env=_env(tmp_path, **extra_env), timeout=60)
    return r, tmp_path / "logs", ws


def _wait_for_warmup(tmp_path, name="prebuild.log", timeout=30):
    log = tmp_path / name
    deadline = time.time() + timeout
    while time.time() < deadline:
        if log.exists() and "warm-up done" in log.read_text():
            return log.read_text()
        time.sleep(0.2)
    raise AssertionError(f"warm-up did not finish: {log.read_text() if log.exists() else '<no log>'}")


def test_stops_module_dev_dashboard(tmp_path):
    # The stub systemctl fails (exit 5), as it would where the unit does not exist: setup goes on.
    r, logs, _ = _run(tmp_path)
    assert r.returncode == 0, r.stderr
    assert "stop dev-dashboard-lab" in (logs / "systemctl.log").read_text()
    _wait_for_warmup(tmp_path)


def test_installs_aspire_at_pin(tmp_path):
    r, logs, _ = _run(tmp_path)
    assert r.returncode == 0, r.stderr
    args = (logs / "install.log").read_text().split()
    assert args[args.index("--version") + 1] == PIN
    assert args[args.index("--install-path") + 1] == str(tmp_path / "lib" / "aspire")
    assert "--skip-path" in args
    link = tmp_path / "usr-local-bin" / "aspire"
    assert link.is_symlink() and os.readlink(link) == str(tmp_path / "lib" / "aspire" / "aspire")
    _wait_for_warmup(tmp_path)


def test_dies_when_aspire_missing_after_install(tmp_path):
    r, _, _ = _run(tmp_path, STUB_INSTALL_NOTHING="1")
    assert r.returncode != 0
    assert "Aspire CLI" in r.stderr


def test_dies_when_aspire_version_differs_from_pin(tmp_path):
    r, _, _ = _run(tmp_path, STUB_ASPIRE_VERSION="17.0.1")
    assert r.returncode != 0
    assert PIN in r.stderr and "17.0.1" in r.stderr


def test_dies_without_the_workspace_folder(tmp_path):
    r, _, _ = _run(tmp_path, TRACKS_SRC_DIR=str(tmp_path / "missing"))
    assert r.returncode != 0
    assert "workflow-aspire not found" in r.stderr


def test_warmup_failure_does_not_fail_setup(tmp_path):
    r, _, _ = _run(tmp_path, STUB_DOTNET_RC="1")
    assert r.returncode == 0, r.stderr
    log = _wait_for_warmup(tmp_path)
    assert "WARN" in log


def test_warmup_never_touches_workspace(tmp_path):
    r, logs, ws = _run(tmp_path)
    assert r.returncode == 0, r.stderr
    _wait_for_warmup(tmp_path)
    calls = (logs / "aspire.log").read_text() + (logs / "dotnet.log").read_text()
    # The warm-up ran the page commands (aspire new, dotnet new web, add package, build) ...
    assert "new aspire-empty" in calls and f"--version {PIN}" in calls
    assert "new web" in calls and "package Dapr.Workflow" in calls and "build" in calls
    # ... in a temp folder, never in the workspace, and removed that folder afterwards.
    assert str(ws) not in calls
    assert sorted(p.name for p in ws.iterdir()) == ["README.md"]
    assert list((tmp_path / "tmp").iterdir()) == []


def test_telemetry_opt_out_for_every_terminal(tmp_path):
    r, _, _ = _run(tmp_path)
    assert r.returncode == 0, r.stderr
    profile = (tmp_path / "profile.d" / "aspire-lab.sh").read_text()
    assert "export ASPIRE_CLI_TELEMETRY_OPTOUT=true" in profile
    assert "export ASPIRE_DASHBOARD_TELEMETRY_OPTOUT=true" in profile
    # Interactive non-login shells (the lab terminals) read bash.bashrc, not profile.d.
    _wait_for_warmup(tmp_path)
    profile_path = str(tmp_path / "profile.d" / "aspire-lab.sh")
    lines = (tmp_path / "bash.bashrc").read_text().splitlines()
    assert lines == [f"[ -r {profile_path} ] && . {profile_path}"]


def test_setup_is_safe_to_run_twice(tmp_path):
    r, _, _ = _run(tmp_path)
    assert r.returncode == 0, r.stderr
    _wait_for_warmup(tmp_path)
    r2 = subprocess.run(["bash", str(tmp_path / "startup.sh")], capture_output=True, text=True,
                        env=_env(tmp_path, prebuild_log="prebuild2.log"), timeout=60)
    assert r2.returncode == 0, r2.stderr
    _wait_for_warmup(tmp_path, "prebuild2.log")
    lines = (tmp_path / "bash.bashrc").read_text().splitlines()
    assert len([line for line in lines if "aspire-lab.sh" in line]) == 1


def test_warmup_never_passes_aspire_cli_version_to_the_cli(tmp_path):
    # ASPIRE_CLI_VERSION in the environment makes the Aspire 17 CLI emulate that version and print
    # a warning on every command, so the pin travels as LAB_ASPIRE_CLI_VERSION.
    r, logs, _ = _run(tmp_path)
    assert r.returncode == 0, r.stderr
    _wait_for_warmup(tmp_path)
    assert (logs / "aspire.log").exists()
    assert not (logs / "aspire-env.log").exists()


NOTICE = "Welcome to Aspire! Telemetry is enabled. Set ASPIRE_CLI_TELEMETRY_OPTOUT=true to opt out."


def test_version_check_reads_past_a_first_run_notice(tmp_path):
    # The VM's first `aspire --version` runs as root before any profile is read: a notice line on
    # stdout before the version must not fail the boot.
    r, logs, _ = _run(tmp_path, STUB_ASPIRE_NOTICE=NOTICE)
    assert r.returncode == 0, r.stderr
    assert f"Aspire CLI {PIN} installed" in r.stdout
    _wait_for_warmup(tmp_path)


def test_version_check_with_a_notice_still_dies_on_a_mismatch(tmp_path):
    r, _, _ = _run(tmp_path, STUB_ASPIRE_NOTICE=NOTICE, STUB_ASPIRE_VERSION="17.0.1")
    assert r.returncode != 0
    assert PIN in r.stderr and "'17.0.1'" in r.stderr


def test_telemetry_opt_out_is_exported_before_the_first_aspire_call(tmp_path):
    r, logs, _ = _run(tmp_path)
    assert r.returncode == 0, r.stderr
    calls = (logs / "aspire-version.log").read_text().splitlines()
    assert calls and all(c == "telemetry_optout=true" for c in calls), calls
    _wait_for_warmup(tmp_path)
