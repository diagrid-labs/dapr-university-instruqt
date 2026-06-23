from types import SimpleNamespace

from collect_github_data import extract_references


def test_extract_from_text_plain_and_keywords():
    text = "Closes #1234. Also fixes #5678 and relates to #9."
    assert extract_references(text, None) == {1234, 5678, 9}


def test_extract_handles_none_text():
    assert extract_references(None, None) == set()


def test_extract_ignores_non_hash_numbers():
    assert extract_references("version 2.0 of v3", None) == set()


def test_extract_from_timeline_cross_referenced():
    ev = SimpleNamespace(
        event="cross-referenced",
        source=SimpleNamespace(issue=SimpleNamespace(number=999)),
    )
    other = SimpleNamespace(event="labeled", source=None)
    assert extract_references(None, [ev, other]) == {999}


def test_extract_unions_text_and_timeline():
    ev = SimpleNamespace(
        event="cross-referenced",
        source=SimpleNamespace(issue=SimpleNamespace(number=42)),
    )
    assert extract_references("see #7", [ev]) == {7, 42}
