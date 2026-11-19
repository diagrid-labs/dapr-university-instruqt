"""The final page of each Instruqt 2.0 lab collects a rating with the Feedback component.

Instruqt 2.0 has no end-of-lab rating screen: Finish & Exit (the Completion component) only ends
the session, so the page must place <instruqt-feedback> itself.
See https://docs.labs.instruqt.com/ui-overview/adding-content/feedback.md
"""

import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[4]

FINAL_PAGES = {
    "dapr-101": "5-pubsub-api",
    "dapr-secrets": "4-swap-the-provider",
    "dapr-pubsub": "6-swap-the-broker",
}

FEEDBACK = re.compile(r'<instruqt-feedback id="([a-z0-9-]+)"></instruqt-feedback>')


@pytest.mark.parametrize("lab,page", FINAL_PAGES.items())
def test_final_page_has_one_feedback_component_before_completion(lab, page):
    text = (REPO / lab / page / "assignment.md").read_text()
    ids = FEEDBACK.findall(text)
    assert ids == [f"{lab}-feedback"]
    assert text.index("<instruqt-feedback") < text.index("<instruqt-completion")


@pytest.mark.parametrize("lab,page", FINAL_PAGES.items())
def test_finish_and_exit_does_not_promise_feedback(lab, page):
    text = (REPO / lab / page / "assignment.md").read_text()
    assert "finish the lab and provide feedback" not in text
