from datetime import datetime
from types import SimpleNamespace

from collect_github_data import (
    collect_issues,
    collect_prs,
    make_classifier,
    Config,
)


def fake_issue(number, body="", is_pr=False, comments=None):
    return SimpleNamespace(
        number=number, title=f"issue {number}", state="open", body=body,
        labels=[], user=SimpleNamespace(login="u"),
        created_at=datetime(2026, 1, 1), updated_at=datetime(2026, 1, 2),
        html_url=f"https://x/issues/{number}",
        pull_request=object() if is_pr else None,
        get_comments=lambda: comments or [],
        get_timeline=lambda: [],
    )


def fake_pr(number, body=""):
    return SimpleNamespace(
        number=number, title=f"pr {number}", state="open", body=body,
        labels=[], user=SimpleNamespace(login="u"),
        created_at=datetime(2026, 1, 1), updated_at=datetime(2026, 1, 2),
        additions=1, deletions=0, changed_files=1,
        html_url=f"https://x/pull/{number}",
        get_files=lambda: [SimpleNamespace(filename="a.go", status="modified",
                                           additions=1, deletions=0, patch="@@")],
        get_comments=lambda: [],
        get_timeline=lambda: [],
    )


def no_refs(numbers):
    return set(), set()


def test_collect_issues_filters_prs():
    repo = SimpleNamespace(
        get_issues=lambda state: [fake_issue(1), fake_issue(2, is_pr=True), fake_issue(3)]
    )
    cfg = Config(owner="o", repo="r", max_issues=10, include_comments=False)
    issues = collect_issues(repo, cfg, no_refs)
    assert sorted(issues) == [1, 3]
    assert issues[1]["type"] == "issue"


def test_collect_issues_caps_at_max():
    repo = SimpleNamespace(get_issues=lambda state: [fake_issue(i) for i in range(1, 6)])
    cfg = Config(owner="o", repo="r", max_issues=2, include_comments=False)
    issues = collect_issues(repo, cfg, no_refs)
    assert len(issues) == 2


def test_collect_prs_includes_files_and_links():
    repo = SimpleNamespace(get_pulls=lambda state: [fake_pr(10, body="Closes #1")])
    cfg = Config(owner="o", repo="r", max_prs=10, include_comments=False,
                 include_pr_files=True)
    classify = lambda numbers: (set(), {1})  # treat #1 as a linked issue
    prs = collect_prs(repo, cfg, classify)
    assert prs[10]["files"][0]["filename"] == "a.go"
    assert prs[10]["linked_issue_numbers"] == [1]


def test_collect_prs_no_files_when_disabled():
    repo = SimpleNamespace(get_pulls=lambda state: [fake_pr(10)])
    cfg = Config(owner="o", repo="r", max_prs=10, include_comments=False,
                 include_pr_files=False)
    prs = collect_prs(repo, cfg, no_refs)
    assert "files" not in prs[10]


def test_classifier_resolves_issue_vs_pr():
    objs = {1: fake_issue(1), 2: fake_issue(2, is_pr=True)}
    repo = SimpleNamespace(get_issue=lambda n: objs[n])
    classify = make_classifier(repo, {})
    prs, issues = classify({1, 2})
    assert prs == {2}
    assert issues == {1}


def _boom():
    from github import GithubException
    raise GithubException(500, {"message": "server"}, None)


def test_collect_one_issue_sets_partial_on_subresource_failure():
    issue = fake_issue(1)
    issue.get_timeline = _boom  # timeline fetch fails mid-collection
    repo = SimpleNamespace(get_issues=lambda state: [issue])
    cfg = Config(owner="o", repo="r", max_issues=10, include_comments=False)
    issues = collect_issues(repo, cfg, no_refs)
    assert issues[1]["partial"] is True  # marked partial, not dropped


def test_collect_one_pr_sets_partial_and_omits_files_on_files_failure():
    pr = fake_pr(10)
    pr.get_files = _boom  # file fetch fails
    repo = SimpleNamespace(get_pulls=lambda state: [pr])
    cfg = Config(owner="o", repo="r", max_prs=10, include_comments=False,
                 include_pr_files=True)
    prs = collect_prs(repo, cfg, no_refs)
    assert prs[10]["partial"] is True
    assert "files" not in prs[10]  # files omitted when the fetch failed


def test_collect_issues_cap_counts_kept_issues_not_iterated():
    # 2 real, 1 PR, 2 real; cap=3 must keep 3 real issues, not stop at the PR.
    repo = SimpleNamespace(get_issues=lambda state: [
        fake_issue(1), fake_issue(2), fake_issue(3, is_pr=True),
        fake_issue(4), fake_issue(5),
    ])
    cfg = Config(owner="o", repo="r", max_issues=3, include_comments=False)
    issues = collect_issues(repo, cfg, no_refs)
    assert sorted(issues) == [1, 2, 4]
