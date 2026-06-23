from collect_github_data import parse_args, Config, SCHEMA_VERSION


def test_schema_version_is_one():
    assert SCHEMA_VERSION == 1


def test_parse_args_required_and_defaults():
    cfg = parse_args(["--owner", "dapr", "--repo", "dapr"])
    assert isinstance(cfg, Config)
    assert cfg.owner == "dapr"
    assert cfg.repo == "dapr"
    assert cfg.out == "./data"
    assert cfg.issues_state == "open"
    assert cfg.max_issues == 100
    assert cfg.prs_state == "open"
    assert cfg.max_prs == 50
    assert cfg.include_pr_files is True
    assert cfg.include_comments is True
    assert cfg.max_comments == 50
    assert cfg.max_patch_bytes == 20000
    assert cfg.seed_issues == []
    assert cfg.neighborhood_depth == 1
    assert cfg.token_env == "GITHUB_TOKEN"
    assert cfg.clean is True


def test_parse_args_flags_and_repeatable_seed():
    cfg = parse_args([
        "--owner", "o", "--repo", "r",
        "--no-pr-files", "--no-comments", "--no-clean",
        "--seed-issue", "1", "--seed-issue", "2",
        "--neighborhood-depth", "2", "--max-patch-bytes", "5000",
    ])
    assert cfg.include_pr_files is False
    assert cfg.include_comments is False
    assert cfg.clean is False
    assert cfg.seed_issues == [1, 2]
    assert cfg.neighborhood_depth == 2
    assert cfg.max_patch_bytes == 5000
