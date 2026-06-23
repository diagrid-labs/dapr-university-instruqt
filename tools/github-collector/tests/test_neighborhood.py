from datetime import datetime
from types import SimpleNamespace

from collect_github_data import collect_neighborhood, make_classifier, Config


def fake_issue(number, body="", is_pr=False):
    return SimpleNamespace(
        number=number, title=f"issue {number}", state="open", body=body,
        labels=[], user=SimpleNamespace(login="u"),
        created_at=datetime(2026, 1, 1), updated_at=datetime(2026, 1, 2),
        html_url=f"https://x/{number}",
        pull_request=object() if is_pr else None,
        get_comments=lambda: [],
        get_timeline=lambda: [],
    )


def test_seeds_only_at_depth_1():
    issue1 = fake_issue(1, body="relates #3")
    repo = SimpleNamespace(get_issue=lambda n: {1: issue1, 3: fake_issue(3)}[n])
    cfg = Config(owner="o", repo="r", seed_issues=[1], neighborhood_depth=1,
                 include_comments=False)
    classify = make_classifier(repo, {})
    issues, prs = {}, {}
    collect_neighborhood(repo, cfg, classify, issues, prs)
    assert set(issues) == {1}          # depth 1 fetches seeds only
    assert issues[1]["is_seed"] is True


def test_depth_2_fetches_direct_neighbor():
    issue1 = fake_issue(1, body="relates #3")
    issue3 = fake_issue(3, body="")
    objs = {1: issue1, 3: issue3}
    repo = SimpleNamespace(get_issue=lambda n: objs[n])
    cfg = Config(owner="o", repo="r", seed_issues=[1], neighborhood_depth=2,
                 include_comments=False)
    classify = make_classifier(repo, {})
    issues, prs = {}, {}
    collect_neighborhood(repo, cfg, classify, issues, prs)
    assert set(issues) == {1, 3}
    assert issues[1]["is_seed"] is True
    assert issues[3]["is_seed"] is False


def test_seed_already_in_flat_gets_flagged():
    repo = SimpleNamespace(get_issue=lambda n: fake_issue(n))
    cfg = Config(owner="o", repo="r", seed_issues=[1], neighborhood_depth=1,
                 include_comments=False)
    classify = make_classifier(repo, {})
    issues = {1: {"number": 1, "is_seed": False}}  # already collected flat
    prs = {}
    collect_neighborhood(repo, cfg, classify, issues, prs)
    assert issues[1]["is_seed"] is True  # flag flipped, not refetched


def test_neighborhood_hard_cap_stops_crawl(monkeypatch):
    import collect_github_data as c
    monkeypatch.setattr(c, "NEIGHBORHOOD_HARD_CAP", 1)
    objs = {1: fake_issue(1), 2: fake_issue(2)}
    repo = SimpleNamespace(get_issue=lambda n: objs[n])
    cfg = Config(owner="o", repo="r", seed_issues=[1, 2],
                 neighborhood_depth=1, include_comments=False)
    classify = make_classifier(repo, {})
    issues, prs = {}, {}
    collect_neighborhood(repo, cfg, classify, issues, prs)
    # cap=1: first frontier item fetched, second hits the cap and stops the crawl.
    assert len(issues) == 1
