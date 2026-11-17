"""dapr-pubsub/scripts/lab-setup.sh is the lab's whole startup script: the module inlines it after
its shared setup, in one strict-mode subshell."""
import os
import subprocess
from pathlib import Path

LAB = Path(__file__).resolve().parents[4] / "dapr-pubsub"
SETUP = LAB / "scripts" / "lab-setup.sh"


def test_lab_startup_script_is_lab_setup():
    hcl = (LAB / "versions.hcl").read_text()
    assert 'lab_startup_script = file("scripts/lab-setup.sh")' in " ".join(hcl.split())


def test_lab_setup_runs_under_strict_mode(tmp_path):
    # Run lab-setup.sh as the module does (one strict-mode subshell, after the module's shared
    # setup has defined log and die), with the prebuild log moved.
    src = tmp_path / "src"
    (src / "pubsub").mkdir(parents=True)
    script = tmp_path / "startup.sh"
    script.write_text(
        "set -euo pipefail\n(\nlog() { :; }\ndie() { echo \"$*\" >&2; exit 1; }\n"
        f"{SETUP.read_text()}\n)\n"
    )
    env = {**os.environ, "TRACKS_SRC_DIR": str(src), "LAB_PREBUILD_LOG": str(tmp_path / "prebuild.log")}
    r = subprocess.run(["bash", str(script)], capture_output=True, text=True, env=env, timeout=60)
    assert r.returncode == 0, r.stderr


def test_lab_setup_fails_without_the_pubsub_folder(tmp_path):
    script = tmp_path / "startup.sh"
    script.write_text(
        "set -euo pipefail\n(\nlog() { :; }\ndie() { echo \"$*\" >&2; exit 1; }\n"
        f"{SETUP.read_text()}\n)\n"
    )
    env = {**os.environ, "TRACKS_SRC_DIR": str(tmp_path / "missing"),
           "LAB_PREBUILD_LOG": str(tmp_path / "prebuild.log")}
    r = subprocess.run(["bash", str(script)], capture_output=True, text=True, env=env, timeout=60)
    assert r.returncode != 0
    assert "pubsub not found" in r.stderr
