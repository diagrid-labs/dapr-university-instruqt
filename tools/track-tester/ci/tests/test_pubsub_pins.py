"""The RabbitMQ image tag lives in four places that must agree: the page 6 assignment's Run block,
the page 6 solve script, the sandbox pre-warm list and the harness variables."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TAG = r"rabbitmq:([0-9][^\s\"']*)"


def tag_in(path):
    m = re.search(TAG, path.read_text())
    assert m, f"no rabbitmq:<tag> in {path}"
    return m.group(1)


def test_rabbitmq_tag_matches_prewarm():
    assignment = tag_in(ROOT / "dapr-pubsub" / "6-swap-the-broker" / "assignment.md")
    solve = tag_in(ROOT / "dapr-pubsub" / "6-swap-the-broker" / "scripts" / "solve.sh")
    prewarm = tag_in(ROOT / "modules" / "dapr-sandbox" / "scripts" / "prewarm.sh")
    variable = tag_in(ROOT / "tools" / "track-tester" / "variables" / "dapr_pubsub.py")
    assert assignment == solve == prewarm == variable
