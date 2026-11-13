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

            def do_POST(self):
                self.rfile.read(int(self.headers.get("Content-Length") or 0))
                status, body = routes.get("POST " + self.path, (404, ""))
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



# ---- Page 3: CloudEvents and raw payloads (demo 3) ----------------------------------------------
P3 = LAB / "3-cloudevents" / "scripts"
ENV_LINE = ('== APP - shipping == shipping received with envelope: {"data":{"orderId":"o-3001"},'
            '"id":"6ce4e90a","source":"order-api","specversion":"1.0","type":"com.dapr.event.sent"}\n'
            '== APP - shipping == shipping parsed CloudEvent id=6ce4e90a type=com.dapr.event.sent '
            'source=order-api\n')
RAW_LINE = '== APP - shipping == shipping received raw: {"orderId":"o-3002","item":"coffee-beans"}\n'


def demo3_up(stubs):
    # Demo 3: shipping subscribes to orders and, only here, to orders-raw.
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata(
        "shipping", [("orders", "DECLARATIVE"), ("orders-raw", "DECLARATIVE")]))})


def test_cloudevents_all_pass(stubs, tmp_path):
    demo3_up(stubs)
    write_log(tmp_path, "dotnet", "Demo3-CloudEvents", "Shipping", "shipping", ENV_LINE + RAW_LINE)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    for name in ("apps-running", "envelope", "raw"):
        assert rc(P3 / f"check-{name}.sh", env) == 0, name


def test_cloudevents_nothing_running_fails_only_running_check(stubs, tmp_path):
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P3 / "check-apps-running.sh", env) == 1
    assert rc(P3 / "check-envelope.sh", env) == 0
    assert rc(P3 / "check-raw.sh", env) == 0


@pytest.mark.parametrize("down", [5101, 5102])
def test_cloudevents_one_app_down_fails_running_check(stubs, tmp_path, down):
    demo3_up_partial = [p for p in (5101, 5102) if p != down]
    for p in demo3_up_partial:
        stubs.up(p)
    stubs.up(3511, {"/v1.0/metadata": (200, metadata(
        "shipping", [("orders", "DECLARATIVE"), ("orders-raw", "DECLARATIVE")]))})
    code, out = run(P3 / "check-apps-running.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert str(down) in out


def test_cloudevents_envelope_missing_lines_fails(stubs, tmp_path):
    demo3_up(stubs)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P3 / "check-envelope.sh", env) == 1
    # Only the first of the two lines: the parsed line is what proves the SDK read it.
    write_log(tmp_path, "python", "demo3-cloud-events", "shipping", "shipping",
              "== APP - shipping == shipping received with envelope: {}\n")
    code, out = run(P3 / "check-envelope.sh", env)
    assert code == 1
    assert "step" in out


def test_cloudevents_raw_missing_line_fails(stubs, tmp_path):
    demo3_up(stubs)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P3 / "check-raw.sh", env) == 1
    write_log(tmp_path, "python", "demo3-cloud-events", "shipping", "shipping", ENV_LINE)
    code, out = run(P3 / "check-raw.sh", env)
    assert code == 1
    assert "step" in out


def test_cloudevents_check_finds_logs_in_any_language(stubs, tmp_path):
    # Java prefixes its lines with a Spring log header, and the learner may use any language.
    demo3_up(stubs)
    write_log(tmp_path, "java", "demo3-cloud-events", "shipping", "shipping",
              "== APP - shipping == 2026-11-13T10:00:00.000Z  INFO 1 --- [shipping] OrderController : "
              "shipping received with envelope: {}\n"
              "== APP - shipping == 2026-11-13T10:00:00.000Z  INFO 1 --- [shipping] OrderController : "
              "shipping parsed CloudEvent id=1 type=t source=s\n"
              "== APP - shipping == 2026-11-13T10:00:00.000Z  INFO 1 --- [shipping] OrderController : "
              "shipping received raw: {}\n")
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P3 / "check-envelope.sh", env) == 0
    assert rc(P3 / "check-raw.sh", env) == 0


def test_cloudevents_logs_of_other_demo_do_not_count(stubs, tmp_path):
    demo3_up(stubs)
    write_log(tmp_path, "dotnet", "Demo1-Subscriptions", "Shipping", "shipping", ENV_LINE + RAW_LINE)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P3 / "check-envelope.sh", env) == 1
    assert rc(P3 / "check-raw.sh", env) == 1


def test_cloudevents_wrong_demo_running(stubs, tmp_path):
    # Page 2's demo is still running: the sidecar on 3511 reports `warehouse`.
    stubs.up(5101)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("warehouse", [("orders", "STREAMING")]))})
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    code, out = run(P3 / "check-apps-running.sh", env)
    assert code == 1
    assert "Ctrl+C" in out
    assert "warehouse" in out
    # Only the one hint: the log checks stay silent.
    assert rc(P3 / "check-envelope.sh", env) == 0
    assert rc(P3 / "check-raw.sh", env) == 0


def test_cloudevents_other_shipping_demo_running_says_ctrl_c(stubs, tmp_path):
    # Demos 1, 3, 4 and 5 all run `shipping` on 3511. Page 1's shipping has no orders-raw
    # subscription, so it is told apart from demo 3 by that, and the log checks stay silent.
    for p in (5101, 5102, 5103):
        stubs.up(p)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("shipping", [("orders", "DECLARATIVE")]))})
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    code, out = run(P3 / "check-apps-running.sh", env)
    assert code == 1
    assert "Ctrl+C" in out
    assert rc(P3 / "check-envelope.sh", env) == 0
    assert rc(P3 / "check-raw.sh", env) == 0


# ---- Page 4: bulk messages (demo 4) -------------------------------------------------------------
P4 = LAB / "4-bulk-messages" / "scripts"
GOOD_ANSWER = ('{"statuses":[{"entryId":"e1","status":"SUCCESS"},'
               '{"entryId":"e2","status":"DROP"}]}')
BATCH_LINE = "== APP - shipping == shipping received batch of 10 orders: bulk-23,bulk-1,bulk-20\n"


def routed_metadata(app_id, topic, path):
    import json
    return json.dumps({"id": app_id, "subscriptions": [
        {"pubsubname": "pubsub", "topic": topic, "rules": [{"path": path}], "type": "DECLARATIVE"}]})


def demo4_up(stubs, answer=GOOD_ANSWER):
    # Demo 4: shipping's only subscription is orders, routed to /orders/bulk.
    stubs.up(5101)
    stubs.up(5102, {"POST /orders/bulk": (200, answer)})
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, routed_metadata("shipping", "orders", "/orders/bulk"))})


def test_bulk_messages_all_pass(stubs, tmp_path):
    demo4_up(stubs)
    write_log(tmp_path, "dotnet", "Demo4-Bulk", "Shipping", "shipping", BATCH_LINE)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    for name in ("apps-running", "batches", "per-entry"):
        assert rc(P4 / f"check-{name}.sh", env) == 0, name


def test_bulk_messages_nothing_running_fails_only_running_check(stubs, tmp_path):
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P4 / "check-apps-running.sh", env) == 1
    assert rc(P4 / "check-batches.sh", env) == 0
    assert rc(P4 / "check-per-entry.sh", env) == 0


@pytest.mark.parametrize("down", [5101, 5102])
def test_bulk_messages_one_app_down_fails_running_check(stubs, tmp_path, down):
    if down != 5101:
        stubs.up(5101)
    if down != 5102:
        stubs.up(5102)
    stubs.up(3511, {"/v1.0/metadata": (200, routed_metadata("shipping", "orders", "/orders/bulk"))})
    code, out = run(P4 / "check-apps-running.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert str(down) in out


def test_bulk_messages_no_batch_line_fails(stubs, tmp_path):
    demo4_up(stubs)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P4 / "check-batches.sh", env) == 1
    # A single-message line is not a batch line.
    write_log(tmp_path, "python", "demo4-bulk", "shipping", "shipping",
              "== APP - shipping == shipping received order o-1\n")
    code, out = run(P4 / "check-batches.sh", env)
    assert code == 1
    assert "step" in out


def test_bulk_messages_check_finds_logs_in_any_language(stubs, tmp_path):
    demo4_up(stubs)
    write_log(tmp_path, "java", "demo4-bulk", "shipping", "shipping",
              "== APP - shipping == 2026-11-13T10:00:00.000Z  INFO 1 --- [shipping] OrderController : "
              "shipping received batch of 5 orders: bulk-1,bulk-2\n")
    assert rc(P4 / "check-batches.sh", {"TRACKS_SRC_DIR": str(tmp_path)}) == 0


def test_bulk_messages_logs_of_other_demo_do_not_count(stubs, tmp_path):
    demo4_up(stubs)
    write_log(tmp_path, "dotnet", "Demo1-Subscriptions", "Shipping", "shipping", BATCH_LINE)
    assert rc(P4 / "check-batches.sh", {"TRACKS_SRC_DIR": str(tmp_path)}) == 1


@pytest.mark.parametrize("answer", [
    '{"statuses":[{"entryId":"e1","status":"SUCCESS"},{"entryId":"e2","status":"SUCCESS"}]}',
    '{"statuses":[{"entryId":"e1","status":"RETRY"},{"entryId":"e2","status":"DROP"}]}',
    '{"statuses":[]}',
    'not json',
])
def test_bulk_messages_per_entry_wrong_statuses_fail(stubs, tmp_path, answer):
    demo4_up(stubs, answer)
    code, out = run(P4 / "check-per-entry.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert "DROP" in out


def test_bulk_messages_per_entry_ignores_field_order_and_spacing(stubs, tmp_path):
    demo4_up(stubs, '{ "statuses": [ {"status": "DROP", "entryId": "e2"}, '
                    '{"status": "SUCCESS", "entryId": "e1"} ] }')
    assert rc(P4 / "check-per-entry.sh", {"TRACKS_SRC_DIR": str(tmp_path)}) == 0


def test_bulk_messages_wrong_demo_running(stubs, tmp_path):
    # Page 2's demo is still running: the sidecar on 3511 reports `warehouse`.
    stubs.up(5101)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("warehouse", [("orders", "STREAMING")]))})
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    code, out = run(P4 / "check-apps-running.sh", env)
    assert code == 1
    assert "Ctrl+C" in out
    assert "warehouse" in out
    assert rc(P4 / "check-batches.sh", env) == 0
    assert rc(P4 / "check-per-entry.sh", env) == 0


@pytest.mark.parametrize("subs", [
    [("orders", "DECLARATIVE")],  # demo 1 and 3: route /orders is not set in this stub, so empty path
    [("orders", "DECLARATIVE"), ("orders-raw", "DECLARATIVE")],  # demo 3
])
def test_bulk_messages_other_shipping_demo_running_says_ctrl_c(stubs, tmp_path, subs):
    # Demos 1, 3, 4 and 5 all run `shipping` on 3511. Only demo 4 routes orders to /orders/bulk.
    for p in (5101, 5102, 5103):
        stubs.up(p)
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("shipping", subs))})
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    code, out = run(P4 / "check-apps-running.sh", env)
    assert code == 1
    assert "Ctrl+C" in out
    assert rc(P4 / "check-batches.sh", env) == 0
    assert rc(P4 / "check-per-entry.sh", env) == 0


@pytest.mark.parametrize("path", ["/orders", "/orders/standard"])
def test_bulk_messages_shipping_with_other_route_says_ctrl_c(stubs, tmp_path, path):
    # Demo 1 (/orders) and demo 5 (/orders/standard) have the same app ID and topic as demo 4.
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3511, {"/v1.0/metadata": (200, routed_metadata("shipping", "orders", path))})
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    code, out = run(P4 / "check-apps-running.sh", env)
    assert code == 1
    assert "Ctrl+C" in out
    assert rc(P4 / "check-batches.sh", env) == 0
    assert rc(P4 / "check-per-entry.sh", env) == 0


# ---- Page 5: routing and dead letters (demo 5) --------------------------------------------------
P5 = LAB / "5-routing-and-dead-letters" / "scripts"
ROUTED_LINES = ("== APP - shipping == shipping standard order o-5001\n"
                "== APP - shipping == shipping express order o-5002\n")
DEAD_LINES = ("== APP - shipping == shipping rejected order o-5003\n"
              "== APP - shipping == shipping dead-lettered order o-5003\n")


def demo5_metadata(app_id="shipping"):
    # As the sidecar of demo 5's shipping reports it: the express rule comes first, then the default
    # route as a rule without a match, and orders-dead is an ordinary subscription.
    import json
    return json.dumps({"id": app_id, "subscriptions": [
        {"pubsubname": "pubsub", "topic": "orders-dead", "rules": [{"path": "/orders/dead"}],
         "deadLetterTopic": "", "type": "DECLARATIVE"},
        {"pubsubname": "pubsub", "topic": "orders",
         "rules": [{"match": 'event.data.priority == "express"', "path": "/orders/express"},
                   {"path": "/orders/standard"}],
         "deadLetterTopic": "orders-dead", "type": "DECLARATIVE"}]})


def demo5_up(stubs):
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, demo5_metadata())})


def test_routing_all_pass(stubs, tmp_path):
    demo5_up(stubs)
    write_log(tmp_path, "dotnet", "Demo5-RoutingDeadLetter", "Shipping", "shipping",
              ROUTED_LINES + DEAD_LINES)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    for name in ("apps-running", "routed", "dead-lettered"):
        assert rc(P5 / f"check-{name}.sh", env) == 0, name


def test_routing_nothing_running_fails_only_running_check(stubs, tmp_path):
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P5 / "check-apps-running.sh", env) == 1
    assert rc(P5 / "check-routed.sh", env) == 0
    assert rc(P5 / "check-dead-lettered.sh", env) == 0


@pytest.mark.parametrize("down", [5101, 5102])
def test_routing_one_app_down_fails_running_check(stubs, tmp_path, down):
    if down != 5101:
        stubs.up(5101)
    if down != 5102:
        stubs.up(5102)
    stubs.up(3511, {"/v1.0/metadata": (200, demo5_metadata())})
    code, out = run(P5 / "check-apps-running.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert str(down) in out


def test_routing_missing_log_lines_fail(stubs, tmp_path):
    demo5_up(stubs)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P5 / "check-routed.sh", env) == 1
    assert rc(P5 / "check-dead-lettered.sh", env) == 1
    # Only the standard order, and only a rejection (no dead-lettering yet).
    write_log(tmp_path, "python", "demo5-routing-dead-letter", "shipping", "shipping",
              "== APP - shipping == shipping standard order o-5001\n"
              "== APP - shipping == shipping rejected order o-5003\n")
    code, out = run(P5 / "check-routed.sh", env)
    assert code == 1
    assert "express" in out
    assert "step 4" in out
    code, out = run(P5 / "check-dead-lettered.sh", env)
    assert code == 1
    assert "step 4" in out


def test_routing_check_finds_logs_in_any_language(stubs, tmp_path):
    demo5_up(stubs)
    write_log(tmp_path, "java", "demo5-routing-dead-letter", "shipping", "shipping",
              "== APP - shipping == 2026-11-13T10:00:00.000Z  INFO 1 --- [shipping] OrderController : "
              "shipping standard order o-5001\n"
              "== APP - shipping == 2026-11-13T10:00:01.000Z  INFO 1 --- [shipping] OrderController : "
              "shipping express order o-5002\n"
              "== APP - shipping == 2026-11-13T10:00:05.000Z  INFO 1 --- [shipping] OrderController : "
              "shipping dead-lettered order o-5003\n")
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P5 / "check-routed.sh", env) == 0
    assert rc(P5 / "check-dead-lettered.sh", env) == 0


def test_routing_logs_of_earlier_demos_do_not_count(stubs, tmp_path):
    demo5_up(stubs)
    write_log(tmp_path, "dotnet", "Demo4-Bulk", "Shipping", "shipping", ROUTED_LINES + DEAD_LINES)
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    assert rc(P5 / "check-routed.sh", env) == 1
    assert rc(P5 / "check-dead-lettered.sh", env) == 1


def test_routing_wrong_demo_running(stubs, tmp_path):
    # Page 2's demo is still running: the sidecar on 3511 reports `warehouse`.
    stubs.up(5101)
    stubs.up(3510, {"/v1.0/metadata": (200, metadata("order-api"))})
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("warehouse", [("orders", "STREAMING")]))})
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    code, out = run(P5 / "check-apps-running.sh", env)
    assert code == 1
    assert "Ctrl+C" in out
    assert "warehouse" in out
    assert rc(P5 / "check-routed.sh", env) == 0
    assert rc(P5 / "check-dead-lettered.sh", env) == 0


@pytest.mark.parametrize("path", ["/orders", "/orders/bulk"])
def test_routing_shipping_with_other_route_says_ctrl_c(stubs, tmp_path, path):
    # Demos 1 and 3 (/orders) and demo 4 (/orders/bulk) have the same app ID and topic as demo 5.
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3511, {"/v1.0/metadata": (200, routed_metadata("shipping", "orders", path))})
    env = {"TRACKS_SRC_DIR": str(tmp_path)}
    code, out = run(P5 / "check-apps-running.sh", env)
    assert code == 1
    assert "Ctrl+C" in out
    assert rc(P5 / "check-routed.sh", env) == 0
    assert rc(P5 / "check-dead-lettered.sh", env) == 0


def test_routing_shipping_still_starting_says_wait(stubs, tmp_path):
    # Shipping's sidecar answers but has loaded no subscriptions yet: wait, do not say Ctrl+C.
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("shipping"))})
    code, out = run(P5 / "check-apps-running.sh", {"TRACKS_SRC_DIR": str(tmp_path)})
    assert code == 1
    assert "starting" in out
    assert "Ctrl+C" not in out


# ---- Page 6: swap the broker (demo 6, the demo 5 apps on RabbitMQ) -------------------------------
P6 = LAB / "6-swap-the-broker" / "scripts"
RABBIT_PORT = 15672


def demo6_metadata(app_id="shipping", pubsub_type="pubsub.rabbitmq"):
    # As the sidecars of demo 6 report it: the demo 5 subscriptions (express rule first) plus a
    # `pubsub` component whose type is the only thing that differs from demo 5.
    import json
    meta = json.loads(demo5_metadata(app_id))
    meta["components"] = [{"name": "pubsub", "type": pubsub_type, "version": "v1", "capabilities": []},
                          {"name": "resiliency", "type": "state.redis", "version": "v1"}]
    return json.dumps(meta)


def queues_body(*names):
    import json
    return json.dumps([{"name": n, "durable": True} for n in names])


def docker_stub(tmp_path, running=True):
    """A fake `docker` first on PATH: `docker ps` prints `rabbitmq` when running, nothing otherwise."""
    d = tmp_path / "bin"
    d.mkdir(exist_ok=True)
    out = "rabbitmq" if running else ""
    f = d / "docker"
    f.write_text(f'#!/bin/sh\n[ "$1" = ps ] && echo "{out}"\nexit 0\n')
    f.chmod(0o755)
    return {"PATH": f"{d}{os.pathsep}{os.environ['PATH']}"}


def demo6_up(stubs, pubsub_type="pubsub.rabbitmq", queues=("shipping-orders", "shipping-orders-dead")):
    if not _free(RABBIT_PORT):
        pytest.skip("port 15672 is in use")
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3510, {"/v1.0/metadata": (200, demo6_metadata("order-api", pubsub_type))})
    stubs.up(3511, {"/v1.0/metadata": (200, demo6_metadata("shipping", pubsub_type))})
    if queues is not None:
        stubs.up(RABBIT_PORT, {"/api/queues": (200, queues_body(*queues))})


def swap_env(tmp_path, running=True):
    return {"TRACKS_SRC_DIR": str(tmp_path), **docker_stub(tmp_path, running)}


SWAP_CHECKS = ("rabbitmq-running", "apps-running", "rabbitmq-component", "dead-lettered")


def test_swap_broker_all_pass(stubs, tmp_path):
    demo6_up(stubs)
    write_log(tmp_path, "dotnet", "Demo5-RoutingDeadLetter", "Shipping", "shipping",
              ROUTED_LINES + DEAD_LINES)
    env = swap_env(tmp_path)
    for name in SWAP_CHECKS:
        assert rc(P6 / f"check-{name}.sh", env) == 0, name


def test_swap_rabbitmq_not_started(stubs, tmp_path):
    # The learner skipped step 1: no rabbitmq container. Only that check says so, and it says what to do.
    env = swap_env(tmp_path, running=False)
    code, out = run(P6 / "check-rabbitmq-running.sh", env)
    assert code == 1
    assert "Start RabbitMQ" in out
    assert "step 1" in out


def test_swap_rabbitmq_not_started_without_docker_output_but_apps_up(stubs, tmp_path):
    # Apps were started without the broker: the first failing check is still the RabbitMQ one.
    demo6_up(stubs, queues=None)
    env = swap_env(tmp_path, running=False)
    assert rc(P6 / "check-rabbitmq-running.sh", env) == 1
    assert rc(P6 / "check-dead-lettered.sh", env) == 1


def test_swap_nothing_running_fails_only_running_checks(stubs, tmp_path):
    env = swap_env(tmp_path)
    assert rc(P6 / "check-rabbitmq-running.sh", env) == 0
    assert rc(P6 / "check-apps-running.sh", env) == 1
    assert rc(P6 / "check-rabbitmq-component.sh", env) == 0
    assert rc(P6 / "check-dead-lettered.sh", env) == 0


@pytest.mark.parametrize("down", [5101, 5102])
def test_swap_one_app_down_fails_running_check(stubs, tmp_path, down):
    if down != 5101:
        stubs.up(5101)
    if down != 5102:
        stubs.up(5102)
    stubs.up(3511, {"/v1.0/metadata": (200, demo6_metadata())})
    code, out = run(P6 / "check-apps-running.sh", swap_env(tmp_path))
    assert code == 1
    assert str(down) in out


def test_swap_broker_check_finds_logs_in_any_language(stubs, tmp_path):
    demo6_up(stubs)
    write_log(tmp_path, "java", "demo5-routing-dead-letter", "shipping", "shipping",
              "== APP - shipping == 2026-11-13T10:00:05.000Z  INFO 1 --- [shipping] OrderController : "
              "shipping dead-lettered order o-5003\n")
    assert rc(P6 / "check-dead-lettered.sh", swap_env(tmp_path)) == 0


def test_swap_broker_wrong_demo_running(stubs, tmp_path):
    # Page 5's demo is still running on Redis: same apps, same routes, only the component differs.
    demo6_up(stubs, pubsub_type="pubsub.redis")
    env = swap_env(tmp_path)
    code, out = run(P6 / "check-apps-running.sh", env)
    assert code == 1
    assert "Ctrl+C" in out
    assert "pubsub.redis" in out
    assert rc(P6 / "check-rabbitmq-component.sh", env) == 0
    assert rc(P6 / "check-dead-lettered.sh", env) == 0


def test_swap_broker_other_page_demo_running(stubs, tmp_path):
    # Page 2's demo is still running: the sidecar on 3511 reports `warehouse`.
    stubs.up(5101)
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("warehouse", [("orders", "STREAMING")]))})
    env = swap_env(tmp_path)
    code, out = run(P6 / "check-apps-running.sh", env)
    assert code == 1
    assert "Ctrl+C" in out
    assert rc(P6 / "check-rabbitmq-component.sh", env) == 0
    assert rc(P6 / "check-dead-lettered.sh", env) == 0


@pytest.mark.parametrize("path", ["/orders", "/orders/bulk"])
def test_swap_broker_shipping_with_other_route_says_ctrl_c(stubs, tmp_path, path):
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3511, {"/v1.0/metadata": (200, routed_metadata("shipping", "orders", path))})
    code, out = run(P6 / "check-apps-running.sh", swap_env(tmp_path))
    assert code == 1
    assert "Ctrl+C" in out


def test_swap_broker_still_starting_says_wait(stubs, tmp_path):
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3511, {"/v1.0/metadata": (200, metadata("shipping"))})
    code, out = run(P6 / "check-apps-running.sh", swap_env(tmp_path))
    assert code == 1
    assert "starting" in out
    assert "Ctrl+C" not in out


def test_swap_broker_component_missing_fails(stubs, tmp_path):
    # order-api's sidecar has no component named pubsub at all.
    import json
    meta = json.loads(demo6_metadata("order-api"))
    meta["components"] = []
    stubs.up(3510, {"/v1.0/metadata": (200, json.dumps(meta))})
    code, out = run(P6 / "check-rabbitmq-component.sh", swap_env(tmp_path))
    assert code == 1
    assert "pubsub" in out


def test_swap_broker_missing_queue_or_log_fails(stubs, tmp_path):
    demo6_up(stubs, queues=("shipping-orders",))
    env = swap_env(tmp_path)
    write_log(tmp_path, "dotnet", "Demo5-RoutingDeadLetter", "Shipping", "shipping", DEAD_LINES)
    code, out = run(P6 / "check-dead-lettered.sh", env)
    assert code == 1
    assert "shipping-orders-dead" in out
    assert "step 4" in out


def test_swap_broker_missing_log_line_fails(stubs, tmp_path):
    demo6_up(stubs)
    env = swap_env(tmp_path)
    code, out = run(P6 / "check-dead-lettered.sh", env)
    assert code == 1
    assert "step 4" in out


def test_swap_broker_management_api_down_fails(stubs, tmp_path):
    demo6_up(stubs, queues=None)
    write_log(tmp_path, "dotnet", "Demo5-RoutingDeadLetter", "Shipping", "shipping", DEAD_LINES)
    code, out = run(P6 / "check-dead-lettered.sh", swap_env(tmp_path))
    assert code == 1
    assert "Start RabbitMQ" in out


def test_swap_broker_component_unreadable_uses_neutral_wording(stubs, tmp_path):
    # Shipping's sidecar has routes but no component list: do not claim Redis is running.
    import json
    meta = json.loads(demo6_metadata())
    del meta["components"]
    stubs.up(5101)
    stubs.up(5102)
    stubs.up(3511, {"/v1.0/metadata": (200, json.dumps(meta))})
    code, out = run(P6 / "check-apps-running.sh", swap_env(tmp_path))
    assert code == 1
    assert "pubsub.redis" not in out
    assert "Redis" not in out
