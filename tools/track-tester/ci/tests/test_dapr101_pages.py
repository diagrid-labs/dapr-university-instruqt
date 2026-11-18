"""Structural checks of the dapr-101 lab pages (titles, run section, final page)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
LAB = ROOT / "dapr-101"

PAGES_WITH_RUN = ["2-dapr-cli", "3-state-management-api", "4-service-invocation-api", "5-pubsub-api"]
STARTS_APPS = ["3-state-management-api", "4-service-invocation-api", "5-pubsub-api"]
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


def test_page2_has_no_install_or_init():
    blocks = re.findall(r"```.*?\n(.*?)```", page_text("2-dapr-cli"), re.S)
    for block in blocks:
        assert "dapr init" not in block
        assert "install.sh" not in block


def test_run_button_note():
    for page in PAGES_WITH_RUN:
        text = page_text(page)
        assert RUN_NOTE in text, page
        assert text.index(RUN_NOTE) < text.index("```bash,run"), page


def test_before_you_start():
    for page in STARTS_APPS:
        assert "## Before you start" in page_text(page), page


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
