"""Run the dapr-pubsub task check scripts against stub HTTP servers and fake app logs.

The checks curl fixed localhost ports (app ports 5101-5103 and Dapr HTTP ports 3510-3512), so the
stubs bind those ports. The tests skip when a port is already taken (for example by a real Dapr
run). App logs are faked under a temporary TRACKS_SRC_DIR passed through the environment.
Each page task appends its own section to this file.
"""
import os
import socket
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

LAB = Path(__file__).resolve().parents[4] / "dapr-pubsub"
PORTS = (5101, 5102, 5103, 3510, 3511, 3512)


def _free(port):
    with socket.socket() as s:
        return s.connect_ex(("127.0.0.1", port)) != 0


pytestmark = pytest.mark.skipif(not all(_free(p) for p in PORTS), reason="a check port is in use")


class Stubs:
    """One server per port, each serving a path -> (status, body) map. A port never started is down."""

    def __init__(self):
        self.servers = []

    def up(self, port, routes=None):
        routes = routes or {}

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


def run(script, env=None):
    r = subprocess.run(["bash", str(script)], env={**os.environ, **(env or {})},
                       capture_output=True, text=True, timeout=60)
    return r.returncode, r.stdout + r.stderr


def rc(script, env=None):
    return run(script, env)[0]


def metadata(app_id, subs=()):
    """A Dapr metadata body: the app id and a list of (topic, type) subscriptions."""
    import json
    return json.dumps({"id": app_id, "subscriptions": [
        {"pubsubname": "pubsub", "topic": t, "type": ty} for t, ty in subs]})


def write_log(src, lang, demo_dir, app_dir, app_id, text, stamp="20260101000000"):
    """A fake `dapr run -f .` app log, as <demo dir>/<app dir>/.dapr/logs/<appID>_app_<stamp>.log."""
    d = src / "pubsub" / lang / demo_dir / app_dir / ".dapr" / "logs"
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{app_id}_app_{stamp}.log").write_text(text)


# ---- Page 1: subscription types (demo 1) --------------------------------------------------------
P1 = LAB / "1-subscription-types" / "scripts"


def demo1_up(stubs, shipping_type="DECLARATIVE", invoicing_type="PROGRAMMATIC"):
    for p in (5101, 5102, 5103):
        stubs.up(p)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("shipping", [("orders", shipping_type)]))})
    stubs.up(3512, {"/v1.0/metadata": (200, metadata("invoicing", [("orders", invoicing_type)]))})


SHIP_LINE = "== APP - shipping == shipping received order o-1001\n"
INV_LINE = "== APP - invoicing == invoicing received order o-1001\n"


def test_subscription_types_all_pass(stubs, tmp_path):
    demo1_up(stubs)
    write_log(tmp_path, "dotnet", "Demo1-Subscriptions", "Shipping", "shipping", SHIP_LINE)
    write_log(tmp_path, "dotnet", "Demo1-Subscriptions", "Invoicing", "invoicing", INV_LINE)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    for name in ("apps-running", "declarative", "programmatic", "both-received"):
        assert rc(P1 / f"check-{name}.sh", env) == 0, name


def test_subscription_types_nothing_running_fails_only_running_check(stubs, tmp_path):
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P1 / "check-apps-running.sh", env) == 1
    assert rc(P1 / "check-declarative.sh", env) == 0
    assert rc(P1 / "check-programmatic.sh", env) == 0
    assert rc(P1 / "check-both-received.sh", env) == 0


@pytest.mark.parametrize("down", [5101, 5102, 5103])
def test_subscription_types_one_app_down_fails_running_check(stubs, tmp_path, down):
    for p in (5101, 5102, 5103):
        if p != down:
            stubs.up(p)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    code, out = run(P1 / "check-apps-running.sh", env)
    assert code == 1
    assert str(down) in out


def test_subscription_types_wrong_type_fails(stubs, tmp_path):
    demo1_up(stubs, shipping_type="PROGRAMMATIC", invoicing_type="DECLARATIVE")
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P1 / "check-declarative.sh", env) == 1
    assert rc(P1 / "check-programmatic.sh", env) == 1
    assert rc(P1 / "check-apps-running.sh", env) == 0


def test_subscription_types_no_orders_subscription_fails(stubs, tmp_path):
    for p in (5101, 5102, 5103):
        stubs.up(p)
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("shipping"))})
    stubs.up(3512, {"/v1.0/metadata": (200, metadata("invoicing", [("other", "PROGRAMMATIC")]))})
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P1 / "check-declarative.sh", env) == 1
    assert rc(P1 / "check-programmatic.sh", env) == 1


def test_subscription_types_metadata_unreachable_is_gated(stubs, tmp_path):
    for p in (5101, 5102, 5103):
        stubs.up(p)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P1 / "check-declarative.sh", env) == 0
    assert rc(P1 / "check-programmatic.sh", env) == 0


def test_subscription_types_both_received_missing_line_fails(stubs, tmp_path):
    demo1_up(stubs)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    # No logs at all.
    assert rc(P1 / "check-both-received.sh", env) == 1
    # Only shipping received it.
    write_log(tmp_path, "python", "demo1-subscriptions", "shipping", "shipping", SHIP_LINE)
    code, out = run(P1 / "check-both-received.sh", env)
    assert code == 1
    assert "invoicing" in out


def test_subscription_types_check_finds_logs_in_any_language(stubs, tmp_path):
    # A learner can use .NET on one page and Java on another: the logs may be in any folder, and
    # Java prefixes its lines with a Spring log header.
    demo1_up(stubs)
    write_log(tmp_path, "java", "demo1-subscriptions", "shipping", "shipping",
              "== APP - shipping == 2026-11-13T10:00:00.000Z  INFO 1 --- [shipping] OrderController : "
              "shipping received order o-1\n")
    write_log(tmp_path, "java", "demo1-subscriptions", "invoicing", "invoicing",
              "== APP - invoicing == 2026-11-13T10:00:00.000Z  INFO 1 --- [invoicing] OrderController : "
              "invoicing received order o-1\n")
    assert rc(P1 / "check-both-received.sh", {"TRACKS_SRC_DIR": str(tmp_path)}) == 0


def test_subscription_types_logs_of_other_demo_do_not_count(stubs, tmp_path):
    # A demo 3 shipping log with "received order" in it is not demo 1's log.
    demo1_up(stubs)
    write_log(tmp_path, "dotnet", "Demo3-CloudEvents", "Shipping", "shipping", SHIP_LINE)
    write_log(tmp_path, "dotnet", "Demo3-CloudEvents", "Invoicing", "invoicing", INV_LINE)
    assert rc(P1 / "check-both-received.sh", {"TRACKS_SRC_DIR": str(tmp_path)}) == 1


def test_subscription_types_wrong_demo_running(stubs, tmp_path):
    # Page 2's demo is still running: order-api and warehouse answer, the sidecar on 3511 reports
    # `warehouse` instead of `shipping`. The first condition must say to press Ctrl+C.
    for p in (5101, 5102, 5103):
        stubs.up(p)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("warehouse", [("orders", "STREAMING")]))})
    stubs.up(3512, {"/v1.0/metadata": (200, metadata("invoicing", [("orders", "PROGRAMMATIC")]))})
    code, out = run(P1 / "check-apps-running.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert "Ctrl+C" in out
    assert "warehouse" in out


def test_subscription_types_other_demo_without_invoicing_says_ctrl_c(stubs, tmp_path):
    # Page 3 to 5's demo: order-api and shipping answer, nothing on 5103.
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("shipping", [("orders", "DECLARATIVE")]))})
    code, out = run(P1 / "check-apps-running.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert "5103" in out
    assert "Ctrl+C" in out


# ---- Page 2: streaming subscriptions (demo 2) ---------------------------------------------------
P2 = LAB / "2-streaming-subscriptions" / "scripts"
WH_LINE = "== APP - warehouse == warehouse received order o-2001\n"


def demo2_up(stubs, warehouse_type="STREAMING"):
    # Only order-api has an app port. The warehouse has no HTTP server, so 5102 stays down.
    stubs.up(5101)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("warehouse", [("orders", warehouse_type)]))})


def test_streaming_all_pass(stubs, tmp_path):
    demo2_up(stubs)
    write_log(tmp_path, "dotnet", "Demo2-Streaming", "Warehouse", "warehouse", WH_LINE)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    for name in ("apps-running", "streaming", "received"):
        assert rc(P2 / f"check-{name}.sh", env) == 0, name


def test_streaming_nothing_running_fails_only_running_check(stubs, tmp_path):
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P2 / "check-apps-running.sh", env) == 1
    assert rc(P2 / "check-streaming.sh", env) == 0
    assert rc(P2 / "check-received.sh", env) == 0


def test_streaming_warehouse_sidecar_down_fails_running_check(stubs, tmp_path):
    stubs.up(5101)
    code, out = run(P2 / "check-apps-running.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert "3511" in out


def test_streaming_order_api_down_fails_running_check(stubs, tmp_path):
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("warehouse", [("orders", "STREAMING")]))})
    code, out = run(P2 / "check-apps-running.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert "5101" in out


def test_streaming_wrong_type_fails(stubs, tmp_path):
    demo2_up(stubs, warehouse_type="PROGRAMMATIC")
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    code, out = run(P2 / "check-streaming.sh", env)
    assert code == 1
    assert "PROGRAMMATIC" in out
    assert rc(P2 / "check-apps-running.sh", env) == 0


def test_streaming_no_orders_subscription_fails(stubs, tmp_path):
    stubs.up(5101)
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("warehouse"))})
    assert rc(P2 / "check-streaming.sh", {"TRACKS_SRC_DIR": str(tmp_path)}) == 1


def test_streaming_metadata_unreachable_is_gated(stubs, tmp_path):
    stubs.up(5101)
    assert rc(P2 / "check-streaming.sh", {"TRACKS_SRC_DIR": str(tmp_path)}) == 0


def test_streaming_received_missing_line_fails(stubs, tmp_path):
    demo2_up(stubs)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P2 / "check-received.sh", env) == 1
    write_log(tmp_path, "python", "demo2-streaming", "warehouse", "warehouse",
              "== APP - warehouse == warehouse dropped unreadable event\n")
    code, out = run(P2 / "check-received.sh", env)
    assert code == 1
    assert "step" in out


def test_streaming_check_finds_logs_in_any_language(stubs, tmp_path):
    # Java prefixes its lines with a Spring log header, and the learner may use any language.
    demo2_up(stubs)
    write_log(tmp_path, "java", "demo2-streaming", "warehouse", "warehouse",
              "== APP - warehouse == 2026-11-13T10:00:00.000Z  INFO 1 --- [warehouse] OrderStream : "
              "warehouse received order o-1\n")
    assert rc(P2 / "check-received.sh", {"TRACKS_SRC_DIR": str(tmp_path)}) == 0


def test_streaming_logs_of_other_demo_do_not_count(stubs, tmp_path):
    demo2_up(stubs)
    write_log(tmp_path, "dotnet", "Demo5-RoutingDeadLetter", "Warehouse", "warehouse", WH_LINE)
    assert rc(P2 / "check-received.sh", {"TRACKS_SRC_DIR": str(tmp_path)}) == 1


def test_streaming_wrong_demo_running(stubs, tmp_path):
    # Page 1's demo is still running: order-api answers, and the sidecar on 3511 reports
    # `shipping` instead of `warehouse`. The first condition must say to press Ctrl+C.
    for p in (5101, 5102, 5103):
        stubs.up(p)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("shipping", [("orders", "DECLARATIVE")]))})
    stubs.up(3512, {"/v1.0/metadata": (200, metadata("invoicing", [("orders", "PROGRAMMATIC")]))})
    code, out = run(P2 / "check-apps-running.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert "Ctrl+C" in out
    assert "shipping" in out

