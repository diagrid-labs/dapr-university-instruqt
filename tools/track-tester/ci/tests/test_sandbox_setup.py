"""Tests for modules/dapr-sandbox/scripts/sandbox-setup.sh, run against stubbed executables."""

import os
import subprocess
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
SCRIPT = REPO / "modules" / "dapr-sandbox" / "scripts" / "sandbox-setup.sh"
MAIN_HCL = REPO / "modules" / "dapr-sandbox" / "main.hcl"

URL = "https://example.test/demo.git"
REF = "abc123"
FOLDER = "pubsub"

STUBS = [
    "docker", "getent", "curl", "git", "code-server", "diagrid-dev-dashboard",
    "dapr", "systemctl", "systemd-run", "ip",
]


def make_env(tmp_path, **overrides):
    bindir = tmp_path / "bin"
    bindir.mkdir()
    calls = tmp_path / "calls"
    calls.touch()
    for name in STUBS:
        stub = bindir / name
        stub.write_text(
            '#!/bin/sh\n'
            f'echo "{name} $*" >> "{calls}"\n'
            f'if [ "{name}" = docker ] && [ "$1" = ps ]; then echo "$STUB_DOCKER_PS"; fi\n'
            "exit 0\n"
        )
        stub.chmod(0o755)
    timeout = bindir / "timeout"  # run the wrapped command, like coreutils timeout
    timeout.write_text('#!/bin/sh\nshift\nexec "$@"\n')
    timeout.chmod(0o755)
    env = {
        "PATH": f"{bindir}:/usr/bin:/bin",
        "HOME": str(tmp_path),
        "LAB_SETUP_LOG": str(tmp_path / "log"),
        "LAB_RESOLV_CONF": str(tmp_path / "resolv.conf"),
        "LAB_DOCKER_DAEMON_JSON": str(tmp_path / "daemon.json"),
        "LAB_CODE_SERVER_LOG": str(tmp_path / "code-server.log"),
        "LAB_DEV_DASHBOARD_LOG": str(tmp_path / "dev-dashboard.log"),
        "DAPR_RUNTIME_VERSION": "1.19.1",
        "DEMO_REPO_URL": URL,
        "DEMO_REPO_REF": REF,
        "EDITOR_FOLDER": FOLDER,
    }
    env.update(overrides)
    return {k: v for k, v in env.items() if v is not None}, calls


def run_script(tmp_path, **overrides):
    env, calls = make_env(tmp_path, **overrides)
    r = subprocess.run(
        ["bash", "-c", f"set -euo pipefail; source '{SCRIPT}'"],
        env=env, capture_output=True, text=True, timeout=60,
    )
    return r, calls.read_text().splitlines()


def test_missing_env_fails_naming_it(tmp_path):
    r, _ = run_script(tmp_path, DEMO_REPO_REF=None)
    assert r.returncode != 0
    assert "DEMO_REPO_REF" in r.stderr


def test_empty_env_fails_naming_it(tmp_path):
    r, _ = run_script(tmp_path, EDITOR_FOLDER="")
    assert r.returncode != 0
    assert "EDITOR_FOLDER" in r.stderr


def test_runs_dapr_init_with_pinned_runtime(tmp_path):
    r, calls = run_script(tmp_path)
    assert r.returncode == 0, r.stderr
    assert "dapr init --runtime-version 1.19.1" in calls


def test_clones_at_ref_and_opens_editor_folder(tmp_path):
    r, _ = run_script(tmp_path)
    assert r.returncode == 0, r.stderr
    deadline = time.time() + 5
    while True:  # code-server is started in the background
        calls = (tmp_path / "calls").read_text().splitlines()
        if any(c.startswith("code-server ") for c in calls) or time.time() > deadline:
            break
        time.sleep(0.1)
    target = f"{tmp_path}/ai-agent-tracks-instruqt"
    assert any(c.startswith("git") and " clone " in c and URL in c and c.endswith(target) for c in calls)
    assert any(c.startswith("git") and c.endswith(f"checkout --quiet {REF}") for c in calls)
    cs = [c for c in calls if c.startswith("code-server ")]
    assert cs and cs[0].endswith(f"{target}/{FOLDER}")


def test_second_run_keeps_clone_and_containers(tmp_path):
    (tmp_path / "ai-agent-tracks-instruqt" / ".git").mkdir(parents=True)
    r, calls = run_script(tmp_path, STUB_DOCKER_PS="abc123")
    assert r.returncode == 0, r.stderr
    assert not any(" clone " in c for c in calls)
    assert not any(c.startswith("dapr init") for c in calls)


def test_helpers_available_to_lab_script(tmp_path):
    env, _ = make_env(tmp_path)
    r = subprocess.run(
        ["bash", "-c", f"source '{SCRIPT}'; declare -F log die bounded wait_for_docker; "
                       'echo "$TRACKS_SRC_DIR"'],
        env=env, capture_output=True, text=True, timeout=60,
    )
    assert r.returncode == 0, r.stderr
    for fn in ("log", "die", "bounded", "wait_for_docker"):
        assert fn in r.stdout
    assert r.stdout.strip().endswith("/ai-agent-tracks-instruqt")


def test_startup_script_order():
    text = MAIN_HCL.read_text()
    a = text.index("source /usr/local/lib/dapr-sandbox/sandbox-setup.sh")
    b = text.index("variable.lab_startup_script", a)
    c = text.index("touch /var/lib/lab-setup/ready", b)
    assert a < b < c


def test_startup_script_fails_clearly_without_sandbox_setup_in_image():
    # An image_ref from before module 2.0.0 has no sandbox-setup.sh: say so instead of a bare
    # "No such file or directory" from `source`.
    text = MAIN_HCL.read_text()
    guard = text.index("[ -r /usr/local/lib/dapr-sandbox/sandbox-setup.sh ] || {")
    assert "image_ref predates module 2.0.0" in text
    assert guard < text.index("source /usr/local/lib/dapr-sandbox/sandbox-setup.sh")
