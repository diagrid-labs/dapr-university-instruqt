"""The version lines on dapr-101 page 2 equal the pins (2.0 has no Instruqt-Var)."""
from pathlib import Path

from read_pin import read_pin

ROOT = Path(__file__).resolve().parents[4]


def test_page2_version_lines_match_pins():
    text = (ROOT / "dapr-101" / "2-dapr-cli" / "assignment.md").read_text()
    cli = read_pin(str(ROOT / "modules" / "dapr-sandbox" / "versions.hcl"), "dapr_cli_version")
    rt = read_pin(str(ROOT / "dapr-101" / "versions.hcl"), "dapr_runtime_version")
    assert f"CLI version: {cli}\n" in text
    assert f"Runtime version: {rt}\n" in text
