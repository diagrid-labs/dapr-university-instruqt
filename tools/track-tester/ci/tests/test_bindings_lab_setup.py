"""dapr-bindings boots Postgres: the module inlines start-postgres.sh (defines start_postgres) and
lab-setup.sh (pre-build, then start_postgres) after its shared setup, in one strict-mode subshell.
CI sources start-postgres.sh on its own, without the module's helpers."""
import os
import subprocess
from pathlib import Path

LAB = Path(__file__).resolve().parents[4] / "dapr-bindings"
START = LAB / "scripts" / "start-postgres.sh"
SETUP = LAB / "scripts" / "lab-setup.sh"
HELPERS = "log() { :; }\ndie() { echo \"$*\" >&2; exit 1; }\n"


def _stubs(tmp_path, ready=True):
    """A `docker` that logs its argv and answers the readiness query, and a no-op `sleep`."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(exist_ok=True)
    log = tmp_path / "docker.log"
    answer = 'case "$*" in *"SELECT 1 FROM comms_log"*) echo 1;; esac' if ready else "case \"$*\" in *SELECT*) exit 2;; esac"
    (bin_dir / "docker").write_text(f'#!/usr/bin/env bash\necho "$*" >> "{log}"\n{answer}\nexit 0\n')
    (bin_dir / "sleep").write_text("#!/usr/bin/env bash\nexit 0\n")
    for f in bin_dir.iterdir():
        f.chmod(0o755)
    return bin_dir, log


def _env(tmp_path, bin_dir, src):
    return {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "TRACKS_SRC_DIR": str(src),
            "LAB_PREBUILD_LOG": str(tmp_path / "prebuild.log")}


def _startup(tmp_path):
    script = tmp_path / "startup.sh"
    script.write_text(f"set -euo pipefail\n(\n{HELPERS}{START.read_text()}\n{SETUP.read_text()}\n)\n")
    return script


def test_lab_startup_script_concatenates_start_postgres_and_lab_setup():
    hcl = " ".join((LAB / "versions.hcl").read_text().split())
    assert 'lab_startup_script = "${file("scripts/start-postgres.sh")}\\n${file("scripts/lab-setup.sh")}"' in hcl


def test_lab_setup_runs_under_strict_mode(tmp_path):
    bin_dir, log = _stubs(tmp_path)
    src = tmp_path / "src"
    (src / "bindings" / "sql").mkdir(parents=True)
    r = subprocess.run(["bash", str(_startup(tmp_path))], capture_output=True, text=True,
                       env=_env(tmp_path, bin_dir, src), timeout=60)
    assert r.returncode == 0, r.stderr
    calls = log.read_text()
    assert calls.index("rm -f bindings-postgres") < calls.index("run -d --name bindings-postgres")
    assert "127.0.0.1:5432:5432" in calls
    assert "/bindings/sql:/docker-entrypoint-initdb.d:ro" in calls
    assert "postgres:18.7" in calls


def test_lab_setup_fails_without_the_bindings_folder(tmp_path):
    bin_dir, _ = _stubs(tmp_path)
    r = subprocess.run(["bash", str(_startup(tmp_path))], capture_output=True, text=True,
                       env=_env(tmp_path, bin_dir, tmp_path / "missing"), timeout=60)
    assert r.returncode != 0
    assert "bindings not found" in r.stderr


def _call_start(tmp_path, body, ready=True):
    bin_dir, log = _stubs(tmp_path, ready)
    sql = tmp_path / "sql"
    sql.mkdir(exist_ok=True)
    cmd = f'set -euo pipefail; source "{START}"; {body.format(sql=sql)}'
    r = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True,
                       env=_env(tmp_path, bin_dir, tmp_path), timeout=60)
    return r, log


def test_start_postgres_twice_succeeds(tmp_path):
    r, log = _call_start(tmp_path, 'start_postgres "{sql}"; start_postgres "{sql}"')
    assert r.returncode == 0, r.stderr
    assert log.read_text().count("rm -f bindings-postgres") == 2


def test_start_postgres_times_out(tmp_path):
    r, log = _call_start(tmp_path, 'start_postgres "{sql}" || exit $?', ready=False)
    assert r.returncode == 1
    assert "ERROR: Postgres did not create the bindings tables within 60 seconds." in r.stderr
    assert log.read_text().count("SELECT 1 FROM comms_log") == 60


def test_start_postgres_needs_no_module_helpers(tmp_path):
    r, _ = _call_start(tmp_path, 'declare -F log die bounded >/dev/null && exit 9; start_postgres "{sql}"')
    assert r.returncode == 0, r.stderr


def _temporary_server_stubs(tmp_path):
    """The Postgres image's first start: a temporary server runs the init SQL on the Unix socket
    only, then shuts down before the final server starts. Here the socket query always succeeds
    and the TCP query never does, as if the final server never came up."""
    bin_dir, log = _stubs(tmp_path, ready=False)
    (bin_dir / "docker").write_text(
        f'#!/usr/bin/env bash\necho "$*" >> "{log}"\n'
        'case "$*" in *"-h 127.0.0.1"*SELECT*) exit 2;; *"SELECT 1 FROM comms_log"*) echo 1;; esac\nexit 0\n')
    return bin_dir, log


def test_start_postgres_waits_for_the_final_server(tmp_path):
    """Tables visible on the socket are not enough: that may be the temporary init server, which
    is about to shut down ('the database system is shutting down'). Only the final server listens
    on TCP, so start_postgres must wait for a TCP connection."""
    bin_dir, _ = _temporary_server_stubs(tmp_path)
    r = subprocess.run(["bash", "-c", f"source {START} && start_postgres /sql"],
                       env=_env(tmp_path, bin_dir, tmp_path), capture_output=True, text=True)
    assert r.returncode == 1, r.stdout + r.stderr


def test_page2_restart_block_waits_for_the_final_server():
    page = (LAB / "2-postgres-output-binding" / "assignment.md").read_text()
    assert ("docker exec bindings-postgres psql -h 127.0.0.1 -U dapr -d dapr "
            "-tAc 'SELECT 1 FROM comms_log' >/dev/null 2>&1 && break") in page
