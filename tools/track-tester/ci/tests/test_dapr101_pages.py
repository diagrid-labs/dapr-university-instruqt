"""Structural checks of the dapr-101 lab pages (titles, run section, final page)."""
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[4]
LAB = ROOT / "dapr-101"

PAGES_WITH_RUN = ["2-dapr-cli", "3-state-management-api", "4-service-invocation-api", "5-pubsub-api"]
STARTS_APPS = ["3-state-management-api", "4-service-invocation-api", "5-pubsub-api"]
# Page 3 is the first page that starts anything, so only the pages after it need to stop
# leftover processes first.
AFTER_APPS = ["4-service-invocation-api", "5-pubsub-api"]
MINUTES = {"1-what-is-dapr": 3, "2-dapr-cli": 3, "3-state-management-api": 5,
           "4-service-invocation-api": 5, "5-pubsub-api": 6}
RUN_NOTE = "When you use the *Run* button on a command, select the matching terminal from the dropdown that appears."


def page_titles():
    """Map each page folder to its pages.hcl title, parsed from the title/file pairs."""
    text = (LAB / "pages.hcl").read_text()
    pairs = re.findall(r'title\s*=\s*"([^"]*)"\s*\n\s*file\s*=\s*"([^"]*)"', text)
    return {Path(f).parent.name: t for t, f in pairs}


def page_text(page):
    return (LAB / page / "assignment.md").read_text()


def test_h1_matches_pages_hcl():
    titles = page_titles()
    assert set(titles) == set(MINUTES)
    for page, title in titles.items():
        assert page_text(page).splitlines()[0] == "# " + title, page


def test_no_instruqt_var():
    for page in MINUTES:
        assert "Instruqt-Var" not in page_text(page), page


def fenced_blocks(text):
    """Return (info string, body) for each fenced block, pairing fences line by line."""
    blocks, info, body = [], None, []
    for line in text.splitlines():
        if line.startswith("```"):
            if info is None:
                info, body = line[3:].strip(), []
            else:
                blocks.append((info, "\n".join(body)))
                info = None
        elif info is not None:
            body.append(line)
    assert info is None, "unclosed code fence"
    return blocks


def test_page2_has_no_install_or_init():
    for info, body in fenced_blocks(page_text("2-dapr-cli")):
        assert "dapr init" not in body, info
        assert "install.sh" not in body, info


def check_run_note(page, text):
    """The run-button note sits in an IMPORTANT callout after the first numbered
    heading and before the first bash,run block."""
    lines = text.splitlines()
    first_heading = next((i for i, l in enumerate(lines) if re.match(r"## \d+\.", l)), None)
    first_run = next((i for i, l in enumerate(lines) if l.startswith("```bash,run")), None)
    note = next((i for i, l in enumerate(lines) if l == "> " + RUN_NOTE), None)
    assert first_heading is not None, f"{page}: no numbered '## <n>.' heading"
    assert first_run is not None, f"{page}: no bash,run block"
    assert note is not None, f"{page}: run-button note missing or not a '> ' quote line"
    assert lines[note - 1] == "> [!IMPORTANT]", f"{page}: note must directly follow a '> [!IMPORTANT]' callout"
    assert first_heading < note - 1 < first_run, f"{page}: callout must be after the first numbered heading and before the first bash,run block"


def test_run_button_note():
    for page in PAGES_WITH_RUN:
        check_run_note(page, page_text(page))


def test_run_button_note_check_rejects_bad_pages():
    good = page_text("4-service-invocation-api")
    check_run_note("good", good)
    callout = "> [!IMPORTANT]\n> " + RUN_NOTE
    assert callout in good
    in_intro = good.replace(callout, "", 1).replace("## 1.", callout + "\n\n## 1.", 1)
    mutations = {
        "NOTE callout": good.replace("> [!IMPORTANT]\n> " + RUN_NOTE, "> [!NOTE]\n> " + RUN_NOTE, 1),
        "placed in the intro": in_intro,
        "no run block": good.replace("```bash,run", "```bash"),
        "no note": good.replace(RUN_NOTE, "x"),
    }
    for name, mutated in mutations.items():
        with pytest.raises(AssertionError):
            check_run_note(name, mutated)


def test_before_you_start():
    for page in AFTER_APPS:
        assert "## Before you start" in page_text(page), page
    assert "## Before you start" not in page_text("3-state-management-api")


def test_stop_section():
    for page in STARTS_APPS:
        assert re.search(r"^## \d+\. Stop the applications", page_text(page), re.M), page


def test_intro_minutes():
    for page, minutes in MINUTES.items():
        assert f"takes about {minutes} minutes to complete" in page_text(page), page


def test_final_page():
    text = page_text("5-pubsub-api")
    assert "university/pubsub" in text
    assert "university/dapr-workflow" in text
    assert "catalyst-101" not in text
    assert "cmcnbdz1r295807jsdm16r929" in text
    assert "<instruqt-completion" in text
    assert "In this final lab" in text
