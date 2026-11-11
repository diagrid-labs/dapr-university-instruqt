"""Run the dapr-secrets task check scripts against a stub HTTP server.

The checks curl fixed localhost ports (5001/5002/5003 and 3500), so the stubs bind those ports.
The tests skip when a port is already taken (for example by a real Dapr run).
"""
import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import subprocess
import pytest

LAB = Path(__file__).resolve().parents[4] / "dapr-secrets"
CH3 = LAB / "3-secret-scoping" / "scripts"
CH4 = LAB / "4-swap-the-provider" / "scripts"
PORTS = (5001, 5002, 5003, 3500)

VAULT = '{"components":[{"name":"secretstore","type":"secretstores.hashicorp.vault","version":"v1"}]}'
FILE = '{"components":[{"name":"secretstore","type":"secretstores.local.file","version":"v1"}]}'


def _free(port):
    with socket.socket() as s:
        return s.connect_ex(("127.0.0.1", port)) != 0


pytestmark = pytest.mark.skipif(not all(_free(p) for p in PORTS), reason="a check port is in use")


class Stubs:
    """One server per port, each serving a path -> (status, body) map. A port never started is down."""

    def __init__(self):
        self.servers = []

    def up(self, port, routes):
        class H(BaseHTTPRequestHandler):
            def do_GET(self):
                status, body = routes.get(self.path, (404, ""))
                self.send_response(status)
                self.end_headers()
                self.wfile.write(body.encode())

            def log_message(self, *a):
                pass

        srv = ThreadingHTTPServer(("127.0.0.1", port), H)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        self.servers.append(srv)

    def close(self):
        for s in self.servers:
            s.shutdown()
            s.server_close()


@pytest.fixture
def stubs():
    s = Stubs()
    yield s
    s.close()


def rc(script, env=None):
    import os
    return subprocess.run(["bash", str(script)], env={**os.environ, **(env or {})},
                          capture_output=True, timeout=60).returncode


def scoped(stubs, a=200, b_orderdb=403, b_payments=200):
    stubs.up(5002, {"/secret/orderdb-password": (a, "x")})
    stubs.up(5003, {"/secret/orderdb-password": (b_orderdb, "x"),
                    "/secret/payments-api-key": (b_payments, "x")})


def test_ch3_all_pass_in_scoped_state(stubs):
    scoped(stubs)
    for name in ("app-a-reads", "app-b-answers", "app-b-refused", "app-b-allowed"):
        assert rc(CH3 / f"check-{name}.sh") == 0, name


def test_ch3_nothing_running_fails_only_answers_checks(stubs):
    # Dependent checks are gated, so a down app yields only the "does not answer" hint.
    assert rc(CH3 / "check-app-b-answers.sh") == 1
    assert rc(CH3 / "check-app-a-reads.sh") == 1
    assert rc(CH3 / "check-app-b-refused.sh") == 0
    assert rc(CH3 / "check-app-b-allowed.sh") == 0


def test_ch3_app_a_not_reading_fails(stubs):
    scoped(stubs, a=500)
    assert rc(CH3 / "check-app-a-reads.sh") == 1


def test_ch3_app_b_stopped_fails_answers_only(stubs):
    stubs.up(5002, {"/secret/orderdb-password": (200, "x")})
    assert rc(CH3 / "check-app-b-answers.sh") == 1
    assert rc(CH3 / "check-app-a-reads.sh") == 0


def test_ch3_app_b_unscoped_not_refused(stubs):
    scoped(stubs, b_orderdb=200)
    assert rc(CH3 / "check-app-b-refused.sh") == 1
    assert rc(CH3 / "check-app-b-answers.sh") == 0


def test_ch3_app_b_other_status_not_refused(stubs):
    scoped(stubs, b_orderdb=500)
    assert rc(CH3 / "check-app-b-refused.sh") == 1


def test_ch3_app_b_payments_refused_fails(stubs):
    scoped(stubs, b_payments=403)
    assert rc(CH3 / "check-app-b-allowed.sh") == 1


def test_ch3_config_present(tmp_path):
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(CH3 / "check-config-present.sh", env) == 1
    d = tmp_path / "secrets" / "python" / "Demo2-Scoping" / "resources"
    d.mkdir(parents=True)
    (d / "config-app-b.yaml").write_text("x")
    assert rc(CH3 / "check-config-present.sh", env) == 0


def swapped(stubs, metadata=VAULT, read=200):
    stubs.up(5001, {"/secret/orderdb-password": (read, "x")})
    stubs.up(3500, {"/v1.0/metadata": (200, metadata)})


def test_ch4_all_pass_with_vault(stubs):
    swapped(stubs)
    for name in ("app-answers", "vault-loaded", "app-reads"):
        assert rc(CH4 / f"check-{name}.sh") == 0, name


def test_ch4_nothing_running_fails_only_answers_check(stubs):
    assert rc(CH4 / "check-app-answers.sh") == 1
    assert rc(CH4 / "check-vault-loaded.sh") == 0
    assert rc(CH4 / "check-app-reads.sh") == 0


def test_ch4_sidecar_metadata_unreachable_is_gated(stubs):
    stubs.up(5001, {"/secret/orderdb-password": (200, "x")})
    assert rc(CH4 / "check-vault-loaded.sh") == 0


def test_ch4_demo1_file_store_fails_vault_loaded_only(stubs):
    swapped(stubs, metadata=FILE)
    assert rc(CH4 / "check-vault-loaded.sh") == 1
    assert rc(CH4 / "check-app-answers.sh") == 0
    assert rc(CH4 / "check-app-reads.sh") == 0


def test_ch4_vault_unreachable_app_cannot_read(stubs):
    swapped(stubs, read=500)
    assert rc(CH4 / "check-vault-loaded.sh") == 0
    assert rc(CH4 / "check-app-reads.sh") == 1


def test_ch4_demo2_still_running_fails_previous_apps_check_only(stubs):
    # Page 3's apps left running in a 2.0 lab: 5001 is down, 5002/5003 answer. Only the specific
    # "stop the Demo2-Scoping apps" hint fails, not the generic "does not answer" one.
    scoped(stubs)
    assert rc(CH4 / "check-previous-apps-stopped.sh") == 1
    assert rc(CH4 / "check-app-answers.sh") == 0
    assert rc(CH4 / "check-vault-loaded.sh") == 0
    assert rc(CH4 / "check-app-reads.sh") == 0


def test_ch4_previous_apps_check_passes_when_swap_app_runs(stubs):
    # The swap app answers: Demo2 apps that might also be up do not matter.
    swapped(stubs)
    stubs.up(5003, {"/secret/orderdb-password": (403, "x")})
    assert rc(CH4 / "check-previous-apps-stopped.sh") == 0


def test_ch4_previous_apps_check_passes_when_nothing_runs(stubs):
    assert rc(CH4 / "check-previous-apps-stopped.sh") == 0
