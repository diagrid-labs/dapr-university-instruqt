from datetime import datetime
from types import SimpleNamespace

from collect_github_data import (
    serialize_issue,
    serialize_pr,
    _serialize_files,
    _iso,
    _login,
)


def ns(**kw):
    return SimpleNamespace(**kw)


def test_iso_and_login_helpers():
    assert _iso(datetime(2026, 6, 1, 9, 0, 0)) == "2026-06-01T09:00:00Z"
    assert _iso(None) is None
    assert _login(ns(login="octocat")) == "octocat"
    assert _login(None) is None


def test_serialize_issue_full_shape():
    issue = ns(
        number=1234, title="Sidecar crashes", state="open", body="When I set ...",
        labels=[ns(name="bug"), ns(name="good first issue")],
        user=ns(login="octocat"),
        created_at=datetime(2026, 6, 1, 9, 0, 0),
        updated_at=datetime(2026, 6, 20, 14, 30, 0),
        html_url="https://github.com/dapr/dapr/issues/1234",
    )
    rec = serialize_issue(
        issue,
        comments=[{"user": "m", "body": "logs?", "created_at": "2026-06-02T08:00:00Z"}],
        linked_pr_numbers=[5678],
        referenced_issue_numbers=[1111, 2222],
        is_seed=True,
        partial=False,
    )
    assert rec["type"] == "issue"
    assert rec["number"] == 1234
    assert rec["state"] == "open"
    assert rec["labels"] == ["bug", "good first issue"]
    assert rec["user"] == "octocat"
    assert rec["created_at"] == "2026-06-01T09:00:00Z"
    assert rec["updated_at"] == "2026-06-20T14:30:00Z"
    assert rec["linked_pr_numbers"] == [5678]
    assert rec["referenced_issue_numbers"] == [1111, 2222]
    assert rec["html_url"] == "https://github.com/dapr/dapr/issues/1234"
    assert rec["is_seed"] is True
    assert rec["partial"] is False
    assert len(rec["comments"]) == 1


def test_serialize_files_truncates_large_patch():
    raw = [ns(filename="a.go", status="modified", additions=30, deletions=5,
              patch="x" * 30000)]
    files = _serialize_files(raw, max_patch_bytes=20000)
    assert files[0]["patch"] is None
    assert files[0]["patch_truncated"] is True
    assert files[0]["filename"] == "a.go"


def test_serialize_files_keeps_small_patch():
    raw = [ns(filename="a.go", status="modified", additions=1, deletions=0,
              patch="@@ -1,4 +1,4 @@")]
    files = _serialize_files(raw, max_patch_bytes=20000)
    assert files[0]["patch"] == "@@ -1,4 +1,4 @@"
    assert files[0]["patch_truncated"] is False


def test_serialize_files_handles_none_patch():
    raw = [ns(filename="bin.dat", status="added", additions=0, deletions=0, patch=None)]
    files = _serialize_files(raw, max_patch_bytes=20000)
    assert files[0]["patch"] is None
    assert files[0]["patch_truncated"] is False


def test_serialize_pr_with_files():
    pr = ns(
        number=5678, title="Fix race", state="open", body="Closes #1234 ...",
        labels=[ns(name="area/runtime")], user=ns(login="contributor"),
        created_at=datetime(2026, 6, 10, 11, 0, 0),
        updated_at=datetime(2026, 6, 21, 16, 0, 0),
        additions=42, deletions=7, changed_files=3,
        html_url="https://github.com/dapr/dapr/pull/5678",
    )
    rec = serialize_pr(
        pr,
        files=[{"filename": "x.go", "status": "modified", "additions": 30,
                "deletions": 5, "patch": "@@", "patch_truncated": False}],
        comments=[],
        linked_issue_numbers=[1234],
        is_seed=False,
        partial=False,
    )
    assert rec["type"] == "pr"
    assert rec["additions"] == 42
    assert rec["deletions"] == 7
    assert rec["changed_files"] == 3
    assert rec["linked_issue_numbers"] == [1234]
    assert rec["files"][0]["filename"] == "x.go"


def test_serialize_pr_omits_files_when_none():
    pr = ns(
        number=5678, title="t", state="open", body="b",
        labels=[], user=ns(login="c"),
        created_at=datetime(2026, 6, 10, 11, 0, 0),
        updated_at=datetime(2026, 6, 21, 16, 0, 0),
        additions=1, deletions=0, changed_files=1,
        html_url="u",
    )
    rec = serialize_pr(pr, files=None, comments=[], linked_issue_numbers=[],
                       is_seed=False, partial=False)
    assert "files" not in rec
