"""The Postgres image tag lives in places that must agree: the lab's start script, page 2's
restart Run block, the sandbox pre-warm list and the harness variables."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TAG = r"postgres:([0-9][^\s\"']*)"


def tags_in(path):
    tags = re.findall(TAG, path.read_text())
    assert tags, f"no postgres:<tag> in {path}"
    return set(tags)


def test_postgres_tag_matches_prewarm():
    prewarm = tags_in(ROOT / "modules" / "dapr-sandbox" / "scripts" / "prewarm.sh")
    assert len(prewarm) == 1
    for path in [
        ROOT / "dapr-bindings" / "scripts" / "start-postgres.sh",
        ROOT / "tools" / "track-tester" / "variables" / "dapr_bindings.py",
    ]:
        assert tags_in(path) == prewarm, path
