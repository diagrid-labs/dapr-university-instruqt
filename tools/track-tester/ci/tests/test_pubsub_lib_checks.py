"""Unit tests for dapr-pubsub/scripts/lib-checks.sh (latest_app_log, port_answers)."""
import os
import socket
import subprocess
import time
from pathlib import Path

LIB = Path(__file__).resolve().parents[4] / "dapr-pubsub" / "scripts" / "lib-checks.sh"


def run(src_dir, snippet):
    env = {**os.environ, "TRACKS_SRC_DIR": str(src_dir)}
    # Mimic a `set -u` caller: the lib must not rely on unset variables.
    return subprocess.run(
        ["bash", "-c", f"set -u; source '{LIB}'; {snippet}"],
        capture_output=True, text=True, env=env,
    )


def make_log(base, rel, app, stamp, mtime):
    d = base / "pubsub" / rel / ".dapr" / "logs"
    d.mkdir(parents=True)
    f = d / f"{app}_app_{stamp}.log"
    f.write_text("x")
    os.utime(f, (mtime, mtime))
    return f


def test_newest_log_across_languages_wins(tmp_path):
    now = time.time()
    make_log(tmp_path, "dotnet/Demo1-Subscriptions/Shipping", "shipping", "20260101100000", now - 100)
    newer = make_log(tmp_path, "python/demo1-subscriptions/shipping", "shipping", "20260101100500", now - 10)
    r = run(tmp_path, "latest_app_log 1 shipping")
    assert r.returncode == 0
    assert r.stdout.strip() == str(newer)


def test_other_app_is_not_matched(tmp_path):
    make_log(tmp_path, "java/demo1-subscriptions/invoicing", "invoicing", "20260101100000", time.time())
    r = run(tmp_path, "latest_app_log 1 shipping")
    assert r.returncode == 0 and r.stdout.strip() == ""


def test_demo6_finds_log_under_demo5_folder(tmp_path):
    f = make_log(tmp_path, "dotnet/Demo5-RoutingDeadLetter/OrderApi", "order-api", "20260101100000", time.time())
    r = run(tmp_path, "latest_app_log 6 order-api")
    assert r.returncode == 0
    assert r.stdout.strip() == str(f)


def test_no_logs_gives_empty_output_and_rc_zero(tmp_path):
    (tmp_path / "pubsub").mkdir()
    r = run(tmp_path, "latest_app_log 3 order-api")
    assert r.returncode == 0 and r.stdout == ""


def test_port_answers_fails_on_free_port(tmp_path):
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    r = run(tmp_path, f"port_answers {port}")
    assert r.returncode != 0


# ---- The helpers on the VM ----------------------------------------------------------------------
# The lab's files are not on the Instruqt VM, so the check and solve scripts cannot reach
# scripts/lib-checks.sh by a repo-relative path there. versions.hcl puts lib-checks.sh in front of
# lab-setup.sh in lab_startup_script, and lab-setup.sh writes the helpers to a fixed path.
LAB = LIB.parents[1]
FIXED_LIB = "/usr/local/lib/dapr-pubsub/lib-checks.sh"
SETUP = LAB / "scripts" / "lab-setup.sh"
PAGE_SCRIPTS = sorted(LAB.glob("*/scripts/*.sh"))


def lib_functions():
    import re
    return sorted(re.findall(r"^([a-z_]+)\(\) \{", LIB.read_text(), re.M))


def test_every_check_and_solve_script_sources_the_fixed_path_first():
    users = [p for p in PAGE_SCRIPTS if "lib-checks.sh" in p.read_text()]
    assert {p.name for p in users} >= {"solve.sh"}
    assert all(p in users for p in PAGE_SCRIPTS if p.name == "solve.sh")
    for p in users:
        text = p.read_text()
        assert f'LIB_CHECKS={FIXED_LIB}' in text, p
        assert '[ -r "$LIB_CHECKS" ] || LIB_CHECKS="$(dirname "$0")/../../scripts/lib-checks.sh"' in text, p
        assert '. "$LIB_CHECKS"' in text, p


def test_lab_startup_script_concatenates_lib_checks_before_lab_setup():
    hcl = (LAB / "versions.hcl").read_text()
    assert ('lab_startup_script = "${file("scripts/lib-checks.sh")}\\n${file("scripts/lab-setup.sh")}"'
            in " ".join(hcl.split()))


def test_lab_setup_installs_every_helper(tmp_path):
    # Run lib-checks.sh + lab-setup.sh as the module does (one strict-mode subshell, after the
    # module's shared setup has defined log and die), with the install dir and prebuild log moved.
    src = tmp_path / "src"
    (src / "pubsub").mkdir(parents=True)
    libdir = tmp_path / "lib"
    script = tmp_path / "startup.sh"
    script.write_text(
        "set -euo pipefail\n(\nlog() { :; }\ndie() { echo \"$*\" >&2; exit 1; }\n"
        f"{LIB.read_text()}\n{SETUP.read_text()}\n)\n"
    )
    env = {**os.environ, "TRACKS_SRC_DIR": str(src), "LAB_CHECKS_LIB_DIR": str(libdir),
           "LAB_PREBUILD_LOG": str(tmp_path / "prebuild.log")}
    r = subprocess.run(["bash", str(script)], capture_output=True, text=True, env=env, timeout=60)
    assert r.returncode == 0, r.stderr
    installed = libdir / "lib-checks.sh"
    assert installed.is_file()
    names = lib_functions()
    assert "latest_app_log" in names and "metadata_component_type" in names
    # Sourced on its own, under set -u, it defines every helper of lib-checks.sh.
    r = subprocess.run(["bash", "-c", f"set -u; . '{installed}'; declare -F"],
                       capture_output=True, text=True, env={"PATH": os.environ["PATH"]})
    assert r.returncode == 0, r.stderr
    defined = {line.split()[-1] for line in r.stdout.splitlines()}
    assert set(names) <= defined
    # And they work: latest_app_log finds a log under TRACKS_SRC_DIR.
    f = make_log(src, "dotnet/Demo2-Streaming/Warehouse", "warehouse", "20260101100000", time.time())
    r = subprocess.run(["bash", "-c", f"set -u; . '{installed}'; latest_app_log 2 warehouse"],
                       capture_output=True, text=True, env={**os.environ, "TRACKS_SRC_DIR": str(src)})
    assert r.stdout.strip() == str(f)
