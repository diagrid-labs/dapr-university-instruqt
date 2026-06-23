from datetime import datetime
from types import SimpleNamespace

import collect_github_data as c


def fake_issue(number, body=""):
    return SimpleNamespace(
        number=number, title=f"issue {number}", state="open", body=body,
        labels=[], user=SimpleNamespace(login="u"),
        created_at=datetime(2026, 1, 1), updated_at=datetime(2026, 1, 2),
        html_url=f"https://x/{number}",
        pull_request=None, get_comments=lambda: [], get_timeline=lambda: [],
    )


def fake_pr(number, body=""):
    return SimpleNamespace(
        number=number, title=f"pr {number}", state="open", body=body,
        labels=[], user=SimpleNamespace(login="u"),
        created_at=datetime(2026, 1, 1), updated_at=datetime(2026, 1, 2),
        additions=1, deletions=0, changed_files=1, html_url=f"https://x/{number}",
        get_files=lambda: [], get_comments=lambda: [], get_timeline=lambda: [],
    )


def test_main_missing_token(monkeypatch):
    monkeypatch.delenv("GITHUB_TOKEN", raising=False)
    assert c.main(["--owner", "o", "--repo", "r"]) == 2


def test_main_repo_not_accessible(monkeypatch, tmp_path):
    monkeypatch.setenv("GITHUB_TOKEN", "x")

    def get_repo(full_name):
        raise c.GithubException(404, {"message": "Not Found"}, None)

    monkeypatch.setattr(c, "build_client",
                        lambda token: SimpleNamespace(get_repo=get_repo))
    rc = c.main(["--owner", "o", "--repo", "r", "--out", str(tmp_path)])
    assert rc == 3


def test_main_happy_path_writes_snapshot(monkeypatch, tmp_path):
    monkeypatch.setenv("GITHUB_TOKEN", "x")
    repo = SimpleNamespace(
        get_issues=lambda state: [fake_issue(1)],
        get_pulls=lambda state: [fake_pr(10)],
        get_issue=lambda n: fake_issue(n),
        get_pull=lambda n: fake_pr(n),
    )
    monkeypatch.setattr(c, "build_client",
                        lambda token: SimpleNamespace(get_repo=lambda f: repo))
    rc = c.main(["--owner", "o", "--repo", "r", "--out", str(tmp_path),
                 "--no-comments"])
    assert rc == 0
    base = tmp_path / "o" / "r"
    assert (base / "manifest.json").exists()
    assert (base / "issues" / "1.json").exists()
    assert (base / "prs" / "10.json").exists()


def test_main_repo_access_other_error_returns_1(monkeypatch, tmp_path):
    monkeypatch.setenv("GITHUB_TOKEN", "x")

    def get_repo(full_name):
        raise c.GithubException(500, {"message": "Server Error"}, None)

    monkeypatch.setattr(c, "build_client",
                        lambda token: SimpleNamespace(get_repo=get_repo))
    rc = c.main(["--owner", "o", "--repo", "r", "--out", str(tmp_path)])
    assert rc == 1  # non-403/404 on repo access is a fatal error


def test_main_collection_error_returns_1(monkeypatch, tmp_path):
    monkeypatch.setenv("GITHUB_TOKEN", "x")

    def boom_issues(state):
        raise c.GithubException(500, {"message": "Server Error"}, None)

    repo = SimpleNamespace(get_issues=boom_issues)
    monkeypatch.setattr(c, "build_client",
                        lambda token: SimpleNamespace(get_repo=lambda f: repo))
    rc = c.main(["--owner", "o", "--repo", "r", "--out", str(tmp_path),
                 "--no-comments"])
    assert rc == 1  # fatal GithubException during collection
