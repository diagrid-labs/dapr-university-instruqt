# GitHub Data Collector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `tools/github-collector/collect_github_data.py`, a build-time script that fetches a snapshot of a GitHub repo's issues and PRs and writes them to local JSON files matching the contract in [`github-collector-design.md`](../../github-collector-design.md).

**Architecture:** A single Python module with focused, independently testable functions. Pure functions (reference extraction, serialization, file writing) are tested with `types.SimpleNamespace` fakes and `tmp_path`; network-touching functions (`collect_issues`, `collect_prs`, `collect_neighborhood`, `main`) are tested with a mocked PyGithub client. Network access is confined to `build_client`/`collect_*`; serialization and writing are pure so the JSON contract is unit-tested against fixtures.

**Tech Stack:** Python 3.12, PyGithub (only runtime dependency), pytest (dev only), `uv` for env/run (matches the tracks).

## Global Constraints

- **Python floor:** `requires-python = ">=3.12"` (matches `image-definition.sh`). One line each, exact values from the spec.
- **Runtime dependencies:** **PyGithub only.** Nothing else runtime-relevant. pytest is dev-only.
- **Output contract is authoritative:** field names, types, and the `data/<owner>/<repo>/{manifest.json,issues/<n>.json,prs/<n>.json}` layout are copied verbatim from the spec §3–§4. `SCHEMA_VERSION = 1`.
- **No network in pure functions:** `extract_references`, `serialize_*`, `_serialize_files`, `write_record`, `write_manifest` must never touch the network — they take already-fetched data.
- **Exit codes:** `0` success; `2` missing/empty token; `3` repo not found/inaccessible (404/403 on the repo); `1` any other fatal error (unrecoverable rate limit/network). Per-item failures never change the exit code — they set `partial: true`.
- **Timestamps:** ISO-8601 UTC `YYYY-MM-DDTHH:MM:SSZ`. `collected_at` is injected into `write_manifest` (not read from a clock inside it) so writing stays pure and testable.
- **Git policy (project rule):** Do **not** run `git add`/`git commit`/`git push` yourself. Each task ends with a **Checkpoint** that shows the suggested staged files and commit message — pause and let the user commit. Only commit if the user explicitly asks in the session.
- **Working directory for tests/commands:** the package dir `tools/github-collector/`. Commands below are written as `(cd tools/github-collector && ...)` so they run from the repo root.

---

### Task 1: Project scaffold, `Config`, and `parse_args`

**Files:**
- Create: `tools/github-collector/pyproject.toml`
- Create: `tools/github-collector/collect_github_data.py`
- Create: `tools/github-collector/tests/test_cli.py`

**Interfaces:**
- Produces:
  - `SCHEMA_VERSION: int = 1`
  - `@dataclass Config` with fields: `owner: str`, `repo: str`, `out: str="./data"`, `issues_state: str="open"`, `max_issues: int=100`, `prs_state: str="open"`, `max_prs: int=50`, `include_pr_files: bool=True`, `include_comments: bool=True`, `max_comments: int=50`, `max_patch_bytes: int=20000`, `seed_issues: list[int]=[]`, `neighborhood_depth: int=1`, `token_env: str="GITHUB_TOKEN"`, `clean: bool=True`
  - `parse_args(argv: list[str] | None = None) -> Config`

- [ ] **Step 1: Create `pyproject.toml`**

```toml
[project]
name = "github-collector"
version = "0.1.0"
description = "Build-time GitHub snapshot collector for Dapr University tracks"
requires-python = ">=3.12"
dependencies = ["PyGithub>=2.5,<3"]

[dependency-groups]
dev = ["pytest>=8"]

[tool.pytest.ini_options]
pythonpath = ["."]
testpaths = ["tests"]
```

- [ ] **Step 2: Write the failing test** — `tools/github-collector/tests/test_cli.py`

```python
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `(cd tools/github-collector && uv run pytest tests/test_cli.py -v)`
Expected: FAIL — `ModuleNotFoundError: No module named 'collect_github_data'`

- [ ] **Step 4: Write minimal implementation** — top of `tools/github-collector/collect_github_data.py`

```python
"""Build-time GitHub snapshot collector. Runs once at VM image creation.

Writes issues/PRs to local JSON under data/<owner>/<repo>/. The readers in each
University track consume this output; this script is the only thing that talks to GitHub.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field

SCHEMA_VERSION = 1


@dataclass
class Config:
    owner: str
    repo: str
    out: str = "./data"
    issues_state: str = "open"
    max_issues: int = 100
    prs_state: str = "open"
    max_prs: int = 50
    include_pr_files: bool = True
    include_comments: bool = True
    max_comments: int = 50
    max_patch_bytes: int = 20000
    seed_issues: list[int] = field(default_factory=list)
    neighborhood_depth: int = 1
    token_env: str = "GITHUB_TOKEN"
    clean: bool = True


def parse_args(argv: list[str] | None = None) -> Config:
    p = argparse.ArgumentParser(
        prog="collect_github_data.py",
        description="Collect a GitHub repo snapshot to local JSON (build-time only).",
    )
    p.add_argument("--owner", required=True, help="Repository owner / org.")
    p.add_argument("--repo", required=True, help="Repository name.")
    p.add_argument("--out", default="./data", help="Output root directory.")
    p.add_argument("--issues-state", choices=["open", "closed", "all"], default="open")
    p.add_argument("--max-issues", type=int, default=100)
    p.add_argument("--prs-state", choices=["open", "closed", "all"], default="open")
    p.add_argument("--max-prs", type=int, default=50)
    p.add_argument("--include-pr-files", dest="include_pr_files",
                   action="store_true", default=True)
    p.add_argument("--no-pr-files", dest="include_pr_files", action="store_false")
    p.add_argument("--include-comments", dest="include_comments",
                   action="store_true", default=True)
    p.add_argument("--no-comments", dest="include_comments", action="store_false")
    p.add_argument("--max-comments", type=int, default=50)
    p.add_argument("--max-patch-bytes", type=int, default=20000)
    p.add_argument("--seed-issue", dest="seed_issues", type=int,
                   action="append", default=[])
    p.add_argument("--neighborhood-depth", type=int, default=1)
    p.add_argument("--token-env", default="GITHUB_TOKEN")
    p.add_argument("--clean", dest="clean", action="store_true", default=True)
    p.add_argument("--no-clean", dest="clean", action="store_false")
    ns = p.parse_args(argv)
    return Config(**vars(ns))
```

- [ ] **Step 5: Run test to verify it passes**

Run: `(cd tools/github-collector && uv run pytest tests/test_cli.py -v)`
Expected: PASS (3 passed)

- [ ] **Step 6: Checkpoint (do not run git yourself)**

Suggested staged files: `tools/github-collector/pyproject.toml`, `tools/github-collector/collect_github_data.py`, `tools/github-collector/tests/test_cli.py`
Suggested message: `feat(collector): scaffold github-collector with Config and CLI parsing`
Pause and let the user commit.

---

### Task 2: Reference extraction (`extract_references`)

**Files:**
- Modify: `tools/github-collector/collect_github_data.py`
- Create: `tools/github-collector/tests/test_references.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `extract_references(text: str | None, timeline: list | None) -> set[int]` — union of `#N` matches in `text` (including close/fix/resolve keywords, which already contain `#N`) and `cross-referenced` timeline events' source issue numbers. Returns candidate numbers only; issue-vs-PR classification happens later via the API (Task 6).

- [ ] **Step 1: Write the failing test** — `tools/github-collector/tests/test_references.py`

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd tools/github-collector && uv run pytest tests/test_references.py -v)`
Expected: FAIL — `ImportError: cannot import name 'extract_references'`

- [ ] **Step 3: Write minimal implementation** — add to `collect_github_data.py` (after `parse_args`)

```python
import re

_REF_RE = re.compile(r"#(\d+)")


def extract_references(text: str | None, timeline: list | None) -> set[int]:
    """Candidate referenced issue/PR numbers from body/comment text and timeline.

    Pure: no network. `#N` matches cover close/fix/resolve keywords too, since those
    phrases contain `#N`. Classification (issue vs PR) is done later via the API.
    """
    refs: set[int] = set()
    if text:
        for m in _REF_RE.finditer(text):
            refs.add(int(m.group(1)))
    if timeline:
        for event in timeline:
            if getattr(event, "event", None) != "cross-referenced":
                continue
            source = getattr(event, "source", None)
            issue = getattr(source, "issue", None) if source is not None else None
            number = getattr(issue, "number", None) if issue is not None else None
            if number is not None:
                refs.add(int(number))
    return refs
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd tools/github-collector && uv run pytest tests/test_references.py -v)`
Expected: PASS (5 passed)

- [ ] **Step 5: Checkpoint (do not run git yourself)**

Suggested staged files: `tools/github-collector/collect_github_data.py`, `tools/github-collector/tests/test_references.py`
Suggested message: `feat(collector): add reference extraction from text and timeline`
Pause and let the user commit.

---

### Task 3: Pure serialization (`_iso`, `_login`, `_serialize_files`, `serialize_issue`, `serialize_pr`)

**Files:**
- Modify: `tools/github-collector/collect_github_data.py`
- Create: `tools/github-collector/tests/test_serialize.py`

**Interfaces:**
- Consumes: nothing (pure; takes already-fetched data).
- Produces:
  - `_iso(dt) -> str | None` — `dt.strftime("%Y-%m-%dT%H:%M:%SZ")` or `None`.
  - `_login(user) -> str | None` — `user.login` or `None`.
  - `_serialize_files(raw_files: list, max_patch_bytes: int) -> list[dict]` — each `{filename,status,additions,deletions,patch,patch_truncated}`; `patch` set to `None` and `patch_truncated=True` when the UTF-8 byte length exceeds `max_patch_bytes`.
  - `serialize_issue(issue, *, comments: list[dict], linked_pr_numbers: list[int], referenced_issue_numbers: list[int], is_seed: bool, partial: bool) -> dict` — the issue contract record.
  - `serialize_pr(pr, *, files: list[dict] | None, comments: list[dict], linked_issue_numbers: list[int], is_seed: bool, partial: bool) -> dict` — the PR contract record; the `files` key is **omitted** when `files is None`.

- [ ] **Step 1: Write the failing test** — `tools/github-collector/tests/test_serialize.py`

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd tools/github-collector && uv run pytest tests/test_serialize.py -v)`
Expected: FAIL — `ImportError: cannot import name 'serialize_issue'`

- [ ] **Step 3: Write minimal implementation** — add to `collect_github_data.py`

```python
def _iso(dt) -> str | None:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ") if dt else None


def _login(user) -> str | None:
    return user.login if user is not None else None


def _serialize_files(raw_files: list, max_patch_bytes: int) -> list[dict]:
    out: list[dict] = []
    for f in raw_files:
        patch = f.patch
        truncated = False
        if patch is not None and len(patch.encode("utf-8")) > max_patch_bytes:
            patch, truncated = None, True
        out.append({
            "filename": f.filename,
            "status": f.status,
            "additions": f.additions,
            "deletions": f.deletions,
            "patch": patch,
            "patch_truncated": truncated,
        })
    return out


def serialize_issue(issue, *, comments: list[dict], linked_pr_numbers: list[int],
                    referenced_issue_numbers: list[int], is_seed: bool,
                    partial: bool) -> dict:
    return {
        "type": "issue",
        "number": issue.number,
        "title": issue.title,
        "state": issue.state,
        "body": issue.body,
        "labels": [label.name for label in issue.labels],
        "user": _login(issue.user),
        "created_at": _iso(issue.created_at),
        "updated_at": _iso(issue.updated_at),
        "comments": comments,
        "linked_pr_numbers": linked_pr_numbers,
        "referenced_issue_numbers": referenced_issue_numbers,
        "html_url": issue.html_url,
        "is_seed": is_seed,
        "partial": partial,
    }


def serialize_pr(pr, *, files: list[dict] | None, comments: list[dict],
                 linked_issue_numbers: list[int], is_seed: bool,
                 partial: bool) -> dict:
    rec = {
        "type": "pr",
        "number": pr.number,
        "title": pr.title,
        "state": pr.state,
        "body": pr.body,
        "labels": [label.name for label in pr.labels],
        "user": _login(pr.user),
        "created_at": _iso(pr.created_at),
        "updated_at": _iso(pr.updated_at),
        "additions": pr.additions,
        "deletions": pr.deletions,
        "changed_files": pr.changed_files,
        "linked_issue_numbers": linked_issue_numbers,
        "comments": comments,
        "html_url": pr.html_url,
        "is_seed": is_seed,
        "partial": partial,
    }
    if files is not None:
        rec["files"] = files
    return rec
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd tools/github-collector && uv run pytest tests/test_serialize.py -v)`
Expected: PASS (8 passed)

- [ ] **Step 5: Checkpoint (do not run git yourself)**

Suggested staged files: `tools/github-collector/collect_github_data.py`, `tools/github-collector/tests/test_serialize.py`
Suggested message: `feat(collector): add pure JSON-contract serializers for issues and PRs`
Pause and let the user commit.

---

### Task 4: Filesystem writers (`write_record`, `write_manifest`)

**Files:**
- Modify: `tools/github-collector/collect_github_data.py`
- Create: `tools/github-collector/tests/test_write.py`

**Interfaces:**
- Consumes: `Config`, `SCHEMA_VERSION`.
- Produces:
  - `write_record(repo_dir: Path, kind: str, record: dict) -> Path` — writes `repo_dir/<kind>/<record["number"]>.json` (kind is `"issues"` or `"prs"`), creating dirs, returns the path.
  - `write_manifest(repo_dir: Path, cfg: Config, counts: dict, seeds: list[int], collected_at: str) -> Path` — writes `repo_dir/manifest.json` per spec §3 and returns the path.

- [ ] **Step 1: Write the failing test** — `tools/github-collector/tests/test_write.py`

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd tools/github-collector && uv run pytest tests/test_write.py -v)`
Expected: FAIL — `ImportError: cannot import name 'write_record'`

- [ ] **Step 3: Write minimal implementation** — add to `collect_github_data.py`

Add `import json` and `from pathlib import Path` to the import block at the top, then:

```python
def write_record(repo_dir: Path, kind: str, record: dict) -> Path:
    directory = repo_dir / kind
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{record['number']}.json"
    path.write_text(json.dumps(record, indent=2), encoding="utf-8")
    return path


def write_manifest(repo_dir: Path, cfg: Config, counts: dict, seeds: list[int],
                   collected_at: str) -> Path:
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "owner": cfg.owner,
        "repo": cfg.repo,
        "collected_at": collected_at,
        "source": "github-rest-api",
        "params": {
            "issues_state": cfg.issues_state,
            "max_issues": cfg.max_issues,
            "prs_state": cfg.prs_state,
            "max_prs": cfg.max_prs,
            "include_pr_files": cfg.include_pr_files,
            "include_comments": cfg.include_comments,
            "max_comments": cfg.max_comments,
            "max_patch_bytes": cfg.max_patch_bytes,
            "neighborhood_depth": cfg.neighborhood_depth,
        },
        "seed_issues": seeds,
        "counts": counts,
    }
    repo_dir.mkdir(parents=True, exist_ok=True)
    path = repo_dir / "manifest.json"
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return path
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd tools/github-collector && uv run pytest tests/test_write.py -v)`
Expected: PASS (3 passed)

- [ ] **Step 5: Checkpoint (do not run git yourself)**

Suggested staged files: `tools/github-collector/collect_github_data.py`, `tools/github-collector/tests/test_write.py`
Suggested message: `feat(collector): add record and manifest writers`
Pause and let the user commit.

---

### Task 5: Rate-limit / retry wrapper (`call_with_retry`) and `log`

**Files:**
- Modify: `tools/github-collector/collect_github_data.py`
- Create: `tools/github-collector/tests/test_retry.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `log(msg: str) -> None` — print to stderr.
  - `call_with_retry(fn, *, max_retries: int = 5, sleep=time.sleep, reset_seconds=_default_reset_seconds)` — call `fn()`; on `RateLimitExceededException` sleep until reset and retry forever; on a 403 `GithubException` (secondary/abuse limit) retry with exponential backoff (`2**attempt`) up to `max_retries`, then re-raise; any other exception propagates immediately. `RateLimitExceededException` is a subclass of `GithubException`, so it is caught first.

- [ ] **Step 1: Write the failing test** — `tools/github-collector/tests/test_retry.py`

```python
import pytest
from github import GithubException, RateLimitExceededException

from collect_github_data import call_with_retry


def test_returns_value_without_error():
    assert call_with_retry(lambda: 42, sleep=lambda s: None) == 42


def test_secondary_limit_backoff_then_success():
    calls = {"n": 0}

    def fn():
        calls["n"] += 1
        if calls["n"] < 3:
            raise GithubException(403, {"message": "secondary rate limit"}, None)
        return "ok"

    slept = []
    result = call_with_retry(fn, max_retries=5, sleep=slept.append)
    assert result == "ok"
    assert calls["n"] == 3
    assert slept == [1, 2]  # 2**0, 2**1


def test_secondary_limit_exhausts_and_raises():
    def fn():
        raise GithubException(403, {"message": "secondary"}, None)

    with pytest.raises(GithubException):
        call_with_retry(fn, max_retries=2, sleep=lambda s: None)


def test_non_403_github_exception_propagates_immediately():
    def fn():
        raise GithubException(500, {"message": "server"}, None)

    with pytest.raises(GithubException):
        call_with_retry(fn, max_retries=5, sleep=lambda s: None)


def test_primary_rate_limit_sleeps_until_reset_then_succeeds():
    calls = {"n": 0}

    def fn():
        calls["n"] += 1
        if calls["n"] == 1:
            raise RateLimitExceededException(403, {"message": "rate"}, {})
        return "done"

    slept = []
    result = call_with_retry(fn, sleep=slept.append, reset_seconds=lambda e: 5)
    assert result == "done"
    assert slept == [5]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd tools/github-collector && uv run pytest tests/test_retry.py -v)`
Expected: FAIL — `ImportError: cannot import name 'call_with_retry'`

- [ ] **Step 3: Write minimal implementation** — add to `collect_github_data.py`

Add `import sys`, `import time`, and `from github import GithubException, RateLimitExceededException` to the imports, then:

```python
def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def _default_reset_seconds(exc) -> int:
    """Seconds to sleep on a primary rate-limit, from the reset header; floor 1s."""
    try:
        reset = int(exc.headers["x-ratelimit-reset"])
        return max(1, reset - int(time.time()))
    except (KeyError, TypeError, ValueError, AttributeError):
        return 60


def call_with_retry(fn, *, max_retries: int = 5, sleep=time.sleep,
                    reset_seconds=_default_reset_seconds):
    """Call fn(), handling GitHub rate limits.

    Primary limit (RateLimitExceededException): sleep until reset, retry indefinitely.
    Secondary/abuse limit (403 GithubException): exponential backoff up to max_retries.
    Other GithubExceptions propagate immediately.
    """
    attempt = 0
    while True:
        try:
            return fn()
        except RateLimitExceededException as exc:
            wait = reset_seconds(exc)
            log(f"primary rate limit hit; sleeping {wait}s until reset")
            sleep(wait)
        except GithubException as exc:
            if exc.status == 403 and attempt < max_retries:
                wait = 2 ** attempt
                log(f"secondary rate limit; backing off {wait}s "
                    f"(attempt {attempt + 1}/{max_retries})")
                sleep(wait)
                attempt += 1
            else:
                raise
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd tools/github-collector && uv run pytest tests/test_retry.py -v)`
Expected: PASS (5 passed)

- [ ] **Step 5: Checkpoint (do not run git yourself)**

Suggested staged files: `tools/github-collector/collect_github_data.py`, `tools/github-collector/tests/test_retry.py`
Suggested message: `feat(collector): add rate-limit-aware retry wrapper`
Pause and let the user commit.

---

### Task 6: Flat collection (`make_classifier`, `_collect_one_issue`, `_collect_one_pr`, `collect_issues`, `collect_prs`)

**Files:**
- Modify: `tools/github-collector/collect_github_data.py`
- Create: `tools/github-collector/tests/test_collect_flat.py`

**Interfaces:**
- Consumes: `extract_references`, `serialize_issue`, `serialize_pr`, `_serialize_files`, `call_with_retry`, `Config`.
- Produces:
  - `make_classifier(repo, cache: dict) -> Callable[[set[int]], tuple[set[int], set[int]]]` — returns `classify(numbers)` that resolves each number via `repo.get_issue(n)` (cached), returning `(pr_numbers, issue_numbers)`; numbers that raise `GithubException` are dropped.
  - `_collect_one_issue(repo, issue, cfg, classify, *, is_seed) -> dict` — fetch comments (capped, most recent) + timeline, extract+classify references, serialize. On a `GithubException` while fetching sub-resources, set `partial=True` and continue.
  - `_collect_one_pr(repo, pr, cfg, classify, *, is_seed) -> dict` — same shape for PRs; fetch files when `cfg.include_pr_files`.
  - `collect_issues(repo, cfg, classify) -> dict[int, dict]` — iterate `repo.get_issues(state=cfg.issues_state)`, skip PRs (`issue.pull_request is not None`), cap at `cfg.max_issues`, keyed by number.
  - `collect_prs(repo, cfg, classify) -> dict[int, dict]` — iterate `repo.get_pulls(state=cfg.prs_state)`, cap at `cfg.max_prs`, keyed by number.

- [ ] **Step 1: Write the failing test** — `tools/github-collector/tests/test_collect_flat.py`

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd tools/github-collector && uv run pytest tests/test_collect_flat.py -v)`
Expected: FAIL — `ImportError: cannot import name 'collect_issues'`

- [ ] **Step 3: Write minimal implementation** — add to `collect_github_data.py`

```python
def make_classifier(repo, cache: dict):
    """Return classify(numbers) -> (pr_numbers, issue_numbers), resolving via the API.

    Each number is looked up once (cached). GitHub surfaces PRs as issues, so
    `pull_request is not None` disambiguates. Numbers that don't resolve are dropped.
    """
    def classify(numbers: set[int]) -> tuple[set[int], set[int]]:
        prs: set[int] = set()
        issues: set[int] = set()
        for number in numbers:
            kind = cache.get(number)
            if kind is None:
                try:
                    obj = call_with_retry(lambda n=number: repo.get_issue(n))
                except GithubException:
                    continue  # unresolved reference -> drop
                kind = "pr" if obj.pull_request is not None else "issue"
                cache[number] = kind
            (prs if kind == "pr" else issues).add(number)
        return prs, issues

    return classify


def _collect_comments(item, cfg) -> tuple[list[dict], set[int]]:
    """Return (serialized comments, extra refs from comment bodies)."""
    if not cfg.include_comments:
        return [], set()
    raw = call_with_retry(lambda: list(item.get_comments()))
    kept = raw[-cfg.max_comments:]
    comments = [{"user": _login(c.user), "body": c.body, "created_at": _iso(c.created_at)}
                for c in kept]
    refs: set[int] = set()
    for c in raw:
        refs |= extract_references(c.body, None)
    return comments, refs


def _collect_one_issue(repo, issue, cfg, classify, *, is_seed: bool) -> dict:
    partial = False
    refs = extract_references(issue.body, None)
    comments: list[dict] = []
    try:
        comments, comment_refs = _collect_comments(issue, cfg)
        refs |= comment_refs
        timeline = call_with_retry(lambda: list(issue.get_timeline()))
        refs |= extract_references(None, timeline)
    except GithubException:
        partial = True
    pr_numbers, issue_numbers = classify(refs)
    return serialize_issue(
        issue,
        comments=comments,
        linked_pr_numbers=sorted(pr_numbers),
        referenced_issue_numbers=sorted(issue_numbers),
        is_seed=is_seed,
        partial=partial,
    )


def _collect_one_pr(repo, pr, cfg, classify, *, is_seed: bool) -> dict:
    partial = False
    refs = extract_references(pr.body, None)
    comments: list[dict] = []
    files: list[dict] | None = None
    try:
        comments, comment_refs = _collect_comments(pr, cfg)
        refs |= comment_refs
        if cfg.include_pr_files:
            raw_files = call_with_retry(lambda: list(pr.get_files()))
            files = _serialize_files(raw_files, cfg.max_patch_bytes)
    except GithubException:
        partial = True
    _, issue_numbers = classify(refs)
    return serialize_pr(
        pr,
        files=files,
        comments=comments,
        linked_issue_numbers=sorted(issue_numbers),
        is_seed=is_seed,
        partial=partial,
    )


def collect_issues(repo, cfg, classify) -> dict[int, dict]:
    records: dict[int, dict] = {}
    for issue in repo.get_issues(state=cfg.issues_state):
        if len(records) >= cfg.max_issues:
            break
        if issue.pull_request is not None:
            continue  # GitHub returns PRs from the issues endpoint; skip them
        records[issue.number] = _collect_one_issue(repo, issue, cfg, classify, is_seed=False)
    log(f"collected {len(records)} issues")
    return records


def collect_prs(repo, cfg, classify) -> dict[int, dict]:
    records: dict[int, dict] = {}
    for pr in repo.get_pulls(state=cfg.prs_state):
        if len(records) >= cfg.max_prs:
            break
        records[pr.number] = _collect_one_pr(repo, pr, cfg, classify, is_seed=False)
    log(f"collected {len(records)} pull requests")
    return records
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd tools/github-collector && uv run pytest tests/test_collect_flat.py -v)`
Expected: PASS (5 passed)

- [ ] **Step 5: Checkpoint (do not run git yourself)**

Suggested staged files: `tools/github-collector/collect_github_data.py`, `tools/github-collector/tests/test_collect_flat.py`
Suggested message: `feat(collector): add flat issue/PR collection with reference classification`
Pause and let the user commit.

---

### Task 7: Neighborhood crawl (`collect_neighborhood`)

**Files:**
- Modify: `tools/github-collector/collect_github_data.py`
- Create: `tools/github-collector/tests/test_neighborhood.py`

**Interfaces:**
- Consumes: `_collect_one_issue`, `_collect_one_pr`, `call_with_retry`, `Config`.
- Produces:
  - `NEIGHBORHOOD_HARD_CAP: int = 200` — internal total-fetch cap that protects build time.
  - `collect_neighborhood(repo, cfg, classify, issues: dict[int, dict], prs: dict[int, dict]) -> None` — breadth-first crawl from `cfg.seed_issues`, mutating `issues`/`prs` in place (deduped by number). Follows `cfg.neighborhood_depth` hops of the spec §5 pseudocode (`for hop in range(depth)`: fetch the current frontier, then set the frontier to its newly referenced numbers). Seeds present from flat collection get `is_seed` flipped to `True`. Reaching `NEIGHBORHOOD_HARD_CAP` logs a warning and stops expanding (does not fail).
  - **Depth note (from spec §5 pseudocode):** the loop runs `depth` times and fetches the frontier each pass; with `depth=1` only the seeds are fetched, `depth=2` adds their direct neighbors, etc. `depth=0` means the caller skips this function entirely (see Task 8).

- [ ] **Step 1: Write the failing test** — `tools/github-collector/tests/test_neighborhood.py`

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd tools/github-collector && uv run pytest tests/test_neighborhood.py -v)`
Expected: FAIL — `ImportError: cannot import name 'collect_neighborhood'`

- [ ] **Step 3: Write minimal implementation** — add to `collect_github_data.py`

```python
NEIGHBORHOOD_HARD_CAP = 200


def collect_neighborhood(repo, cfg, classify, issues: dict[int, dict],
                         prs: dict[int, dict]) -> None:
    """Breadth-first crawl from cfg.seed_issues, mutating issues/prs in place.

    Follows the spec §5 pseudocode: loop `neighborhood_depth` times, fetching the
    current frontier each pass and deduping by number against what's already collected.
    """
    seeds = set(cfg.seed_issues)
    # Flag seeds that were already collected by the flat pass.
    for seed in seeds:
        if seed in issues:
            issues[seed]["is_seed"] = True
        elif seed in prs:
            prs[seed]["is_seed"] = True

    frontier = set(seeds)
    collected = set(issues) | set(prs)
    fetches = 0

    for _hop in range(cfg.neighborhood_depth):
        next_frontier: set[int] = set()
        for number in sorted(frontier):
            if number in collected:
                continue
            if fetches >= NEIGHBORHOOD_HARD_CAP:
                log(f"WARNING: neighborhood hard cap {NEIGHBORHOOD_HARD_CAP} reached; "
                    f"stopping crawl")
                return
            try:
                probe = call_with_retry(lambda n=number: repo.get_issue(n))
            except GithubException:
                collected.add(number)
                continue
            fetches += 1
            is_seed = number in seeds
            if probe.pull_request is not None:
                pr = call_with_retry(lambda n=number: repo.get_pull(n))
                record = _collect_one_pr(repo, pr, cfg, classify, is_seed=is_seed)
                prs[number] = record
                next_frontier |= set(record["linked_issue_numbers"])
            else:
                record = _collect_one_issue(repo, probe, cfg, classify, is_seed=is_seed)
                issues[number] = record
                next_frontier |= set(record["linked_pr_numbers"])
                next_frontier |= set(record["referenced_issue_numbers"])
            collected.add(number)
        frontier = next_frontier - collected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd tools/github-collector && uv run pytest tests/test_neighborhood.py -v)`
Expected: PASS (3 passed)

- [ ] **Step 5: Checkpoint (do not run git yourself)**

Suggested staged files: `tools/github-collector/collect_github_data.py`, `tools/github-collector/tests/test_neighborhood.py`
Suggested message: `feat(collector): add bounded neighborhood crawl from seed issues`
Pause and let the user commit.

---

### Task 8: Orchestration (`build_client`, `_now_iso`, `main`) and exit codes

**Files:**
- Modify: `tools/github-collector/collect_github_data.py`
- Create: `tools/github-collector/tests/test_main.py`

**Interfaces:**
- Consumes: all prior functions.
- Produces:
  - `build_client(token: str) -> Github` — `Github(auth=Auth.Token(token))`.
  - `_now_iso() -> str` — current UTC time as `YYYY-MM-DDTHH:MM:SSZ`.
  - `main(argv: list[str] | None = None) -> int` — orchestrate: parse args, read token from `cfg.token_env` (exit `2` if missing/empty), build client, resolve repo (exit `3` on 403/404, exit `1` on other `GithubException`), optionally wipe the repo subtree (`--clean`), run flat collection + neighborhood crawl (when seeds given and depth > 0), write all records + manifest, return `0`. An unrecoverable `RateLimitExceededException` during collection returns `1`.
  - Module ends with `if __name__ == "__main__": raise SystemExit(main())`.

- [ ] **Step 1: Write the failing test** — `tools/github-collector/tests/test_main.py`

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd tools/github-collector && uv run pytest tests/test_main.py -v)`
Expected: FAIL — `AttributeError: module 'collect_github_data' has no attribute 'main'`

- [ ] **Step 3: Write minimal implementation** — add to `collect_github_data.py`

Add `import os`, `import shutil`, `from datetime import datetime, timezone`, and extend the GitHub import to `from github import Github, Auth, GithubException, RateLimitExceededException`. Then:

```python
def build_client(token: str) -> Github:
    return Github(auth=Auth.Token(token))


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main(argv: list[str] | None = None) -> int:
    cfg = parse_args(argv)

    token = os.environ.get(cfg.token_env, "").strip()
    if not token:
        log(f"ERROR: build-time token env '{cfg.token_env}' is missing or empty")
        return 2

    client = build_client(token)
    try:
        repo = call_with_retry(lambda: client.get_repo(f"{cfg.owner}/{cfg.repo}"))
    except GithubException as exc:
        if exc.status in (403, 404):
            log(f"ERROR: repo {cfg.owner}/{cfg.repo} not found or not accessible "
                f"({exc.status})")
            return 3
        log(f"ERROR: failed to access repo {cfg.owner}/{cfg.repo}: {exc}")
        return 1

    repo_dir = Path(cfg.out) / cfg.owner / cfg.repo
    if cfg.clean and repo_dir.exists():
        shutil.rmtree(repo_dir)

    classify = make_classifier(repo, {})
    try:
        issues = collect_issues(repo, cfg, classify)
        prs = collect_prs(repo, cfg, classify)
        if cfg.seed_issues and cfg.neighborhood_depth > 0:
            collect_neighborhood(repo, cfg, classify, issues, prs)
    except RateLimitExceededException:
        log("ERROR: unrecoverable rate limit during collection")
        return 1
    except GithubException as exc:
        log(f"ERROR: fatal GitHub error during collection: {exc}")
        return 1

    for number, record in issues.items():
        write_record(repo_dir, "issues", record)
    for number, record in prs.items():
        write_record(repo_dir, "prs", record)

    write_manifest(repo_dir, cfg,
                   counts={"issues": len(issues), "prs": len(prs)},
                   seeds=cfg.seed_issues,
                   collected_at=_now_iso())
    log(f"done: {len(issues)} issues, {len(prs)} prs -> {repo_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd tools/github-collector && uv run pytest tests/test_main.py -v)`
Expected: PASS (3 passed)

- [ ] **Step 5: Run the full suite**

Run: `(cd tools/github-collector && uv run pytest -v)`
Expected: PASS (all tests from Tasks 1–8 green)

- [ ] **Step 6: Checkpoint (do not run git yourself)**

Suggested staged files: `tools/github-collector/collect_github_data.py`, `tools/github-collector/tests/test_main.py`
Suggested message: `feat(collector): add main orchestration and exit-code handling`
Pause and let the user commit.

---

### Task 9: README and `image-definition.sh` integration

**Files:**
- Create: `tools/github-collector/README.md`
- Modify: `ai-agents-deepagents/_setup/image-definition.sh`

**Interfaces:**
- Consumes: the completed CLI (`main` / `parse_args`).
- Produces: a documented invocation and a build-time collection step wired into the deepagents track's image build. (Other tracks add the same step in their own `_setup/image-definition.sh` as they are created — note this in the README.)

- [ ] **Step 1: Verify the CLI help renders** (smoke test, no GitHub needed)

Run: `(cd tools/github-collector && uv run python collect_github_data.py --help)`
Expected: usage text listing `--owner`, `--repo`, `--max-prs`, `--seed-issue`, etc., exit 0.

- [ ] **Step 2: Create `tools/github-collector/README.md`**

````markdown
# GitHub Data Collector

Build-time script that snapshots a GitHub repo's issues and PRs to local JSON under
`data/<owner>/<repo>/`. Runs **once at VM image creation** — never at sandbox startup
or app runtime. The University tracks read this snapshot locally (no `gh` CLI, no token,
no network in the running sandbox).

See [`docs/github-collector-design.md`](../../docs/github-collector-design.md) for the
full spec and JSON contract.

## Usage

```bash
# Flat batch (Track 1 — PR digest)
GITHUB_TOKEN=ghp_xxx uv run python collect_github_data.py \
  --owner dapr --repo dapr --max-prs 50 --max-issues 100 --out ./data

# Seed neighborhood (Track 5 — deep investigation)
GITHUB_TOKEN=ghp_xxx uv run python collect_github_data.py \
  --owner dapr --repo dapr --seed-issue 1234 --seed-issue 5678 \
  --neighborhood-depth 2 --out ./data
```

The build-time token is read from `$GITHUB_TOKEN` (override with `--token-env`) and is
absent from the running sandbox. Exit codes: `0` ok, `2` missing token, `3` repo
inaccessible, `1` other fatal error.

## Tests

```bash
uv run pytest -v
```

## Integrating a track

In each track's `_setup/image-definition.sh`, after the Ollama pulls, add a collection
step (see the deepagents track for the canonical example). Point the runtime reader at
`<out>/<owner>/<repo>/`.
````

- [ ] **Step 3: Add the collection step to `ai-agents-deepagents/_setup/image-definition.sh`**

Append after the GitHub CLI install block (end of file):

```bash
# --- GitHub snapshot (build-time only) ---------------------------------------
# Collect the repo snapshot once, at image build time, into JSON the track reads
# locally at runtime. BUILD_GITHUB_TOKEN is injected as a build-only secret and is
# absent from the running sandbox. See tools/github-collector/README.md.
sudo apt install pipx -y
pipx install uv
GITHUB_TOKEN="$BUILD_GITHUB_TOKEN" \
  uv run --project tools/github-collector \
    tools/github-collector/collect_github_data.py \
    --owner dapr --repo dapr \
    --seed-issue 1234 --neighborhood-depth 2 \
    --out /opt/track-data
```

- [ ] **Step 4: Re-run the full suite to confirm nothing regressed**

Run: `(cd tools/github-collector && uv run pytest -v)`
Expected: PASS (all tests green)

- [ ] **Step 5: Checkpoint (do not run git yourself)**

Suggested staged files: `tools/github-collector/README.md`, `ai-agents-deepagents/_setup/image-definition.sh`
Suggested message: `docs(collector): add README and wire collection into deepagents image build`
Pause and let the user commit.

---

## Notes for the implementer

- **Verify PyGithub specifics against the installed version** when tests first exercise the real client (exception constructor args, `Auth.Token`, `issue.get_timeline()` event names). The unit tests use fakes, so a mismatch only surfaces in a live run; the `--help` smoke test (Task 9) and a real run against a small public repo are the integration check.
- **`--include-pr-files` / `--no-pr-files`** uses argparse `store_true`/`store_false` on the same `dest`; the default lives on the `store_true` action. Same pattern for `--include-comments`/`--no-comments` and `--clean`/`--no-clean`.
- **Depth semantics** follow the spec §5 pseudocode literally (see Task 7's interface note). If the build team decides "depth N = seed + N hops of neighbors" instead, change the seed handling to always fetch seeds before the hop loop and adjust the two neighborhood tests — flag this as an open question against spec §9.
