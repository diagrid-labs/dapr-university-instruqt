import json

from collect_github_data import write_record, write_manifest, Config, SCHEMA_VERSION


def test_write_record_path_and_content(tmp_path):
    path = write_record(tmp_path, "issues", {"number": 1234, "title": "t"})
    assert path == tmp_path / "issues" / "1234.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["number"] == 1234
    assert data["title"] == "t"


def test_write_record_prs_dir(tmp_path):
    path = write_record(tmp_path, "prs", {"number": 5678})
    assert path == tmp_path / "prs" / "5678.json"
    assert path.exists()


def test_write_manifest(tmp_path):
    cfg = Config(owner="dapr", repo="dapr", seed_issues=[1234, 5678])
    path = write_manifest(
        tmp_path, cfg,
        counts={"issues": 100, "prs": 50},
        seeds=[1234, 5678],
        collected_at="2026-06-23T10:15:00Z",
    )
    assert path == tmp_path / "manifest.json"
    m = json.loads(path.read_text(encoding="utf-8"))
    assert m["schema_version"] == SCHEMA_VERSION
    assert m["owner"] == "dapr"
    assert m["repo"] == "dapr"
    assert m["collected_at"] == "2026-06-23T10:15:00Z"
    assert m["source"] == "github-rest-api"
    assert m["seed_issues"] == [1234, 5678]
    assert m["counts"] == {"issues": 100, "prs": 50}
    assert m["params"]["issues_state"] == "open"
    assert m["params"]["max_issues"] == 100
    assert m["params"]["prs_state"] == "open"
    assert m["params"]["max_prs"] == 50
    assert m["params"]["include_pr_files"] is True
    assert m["params"]["include_comments"] is True
    assert m["params"]["max_comments"] == 50
    assert m["params"]["max_patch_bytes"] == 20000
    assert m["params"]["neighborhood_depth"] == 1
