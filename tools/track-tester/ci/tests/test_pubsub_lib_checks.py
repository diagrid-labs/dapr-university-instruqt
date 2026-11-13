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
