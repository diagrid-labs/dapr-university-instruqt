"""Build-time GitHub snapshot collector. Runs once at VM image creation.

Writes issues/PRs to local JSON under data/<owner>/<repo>/. The readers in each
University track consume this output; this script is the only thing that talks to GitHub.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from github import Github, Auth, GithubException, RateLimitExceededException

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


def write_record(repo_dir: Path, kind: str, record: dict) -> Path:
    """Write a serialized issue or PR record to disk.

    Args:
        repo_dir: base directory (e.g., data/owner/repo/)
        kind: "issues" or "prs"
        record: serialized record dict with a "number" key

    Returns:
        Path to the written file
    """
    directory = repo_dir / kind
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{record['number']}.json"
    path.write_text(json.dumps(record, indent=2), encoding="utf-8")
    return path


def write_manifest(repo_dir: Path, cfg: Config, counts: dict, seeds: list[int],
                   collected_at: str) -> Path:
    """Write the manifest.json summarizing the collection run.

    Args:
        repo_dir: base directory (e.g., data/owner/repo/)
        cfg: Config object with collection parameters
        counts: dict with "issues" and "prs" counts
        seeds: list of seed issue numbers (from cfg.seed_issues)
        collected_at: ISO-8601 UTC timestamp string

    Returns:
        Path to the written manifest.json
    """
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


def log(msg: str) -> None:
    """Print a progress/diagnostic message to stdout (flushed for live output).

    Encoding-safe: GitHub titles may contain emoji/non-ASCII. On Windows a
    redirected stdout can default to a non-UTF-8 code page, so fall back to
    replacing unencodable characters instead of crashing the run.

    Args:
        msg: message to print
    """
    try:
        print(msg, file=sys.stdout, flush=True)
    except UnicodeEncodeError:
        enc = sys.stdout.encoding or "utf-8"
        print(msg.encode(enc, errors="replace").decode(enc),
              file=sys.stdout, flush=True)


def _short(text: str | None, limit: int = 72) -> str:
    """Collapse a title/body to a single trimmed line for progress output."""
    text = (text or "").strip().replace("\n", " ")
    return text if len(text) <= limit else text[: limit - 3] + "..."


def _default_reset_seconds(exc) -> int:
    """Seconds to sleep on a primary rate-limit, from the reset header; floor 1s.

    Args:
        exc: RateLimitExceededException with headers dict

    Returns:
        Seconds to sleep until the rate limit resets
    """
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

    Args:
        fn: callable to invoke
        max_retries: max attempts for secondary (403) rate limits
        sleep: callable to sleep (default: time.sleep, overridable for tests)
        reset_seconds: callable to extract reset time from exception
                      (default: _default_reset_seconds, overridable for tests)

    Returns:
        Return value of fn()

    Raises:
        GithubException: if a non-rate-limit exception occurs or secondary limit
                        is exhausted
        RateLimitExceededException: should not be raised (sleep and retry forever)
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


def make_classifier(repo, cache: dict):
    """Return classify(numbers) -> (pr_numbers, issue_numbers), resolving via the API.

    Each number is looked up once (cached). GitHub surfaces PRs as issues, so
    `pull_request is not None` disambiguates. Numbers that don't resolve are dropped.

    Args:
        repo: GitHub repository object (PyGithub)
        cache: dict to cache lookups (mutated; maps number to "pr" or "issue")

    Returns:
        Callable that takes a set of numbers and returns (pr_set, issue_set)
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
    """Return (serialized comments, extra refs from comment bodies).

    Args:
        item: issue or PR object
        cfg: Config object with include_comments and max_comments settings

    Returns:
        Tuple of (list of serialized comment dicts, set of referenced numbers)
    """
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
    """Fetch and serialize a single issue with its sub-resources.

    Args:
        repo: GitHub repository object
        issue: GitHub issue object
        cfg: Config object
        classify: classifier function from make_classifier
        is_seed: whether this issue was a seed issue

    Returns:
        Serialized issue dict per serialize_issue contract
    """
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
    """Fetch and serialize a single PR with its sub-resources.

    Args:
        repo: GitHub repository object
        pr: GitHub PR object
        cfg: Config object
        classify: classifier function from make_classifier
        is_seed: whether this PR was a seed issue

    Returns:
        Serialized PR dict per serialize_pr contract
    """
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
    """Iterate and collect issues from the repo.

    Skips PRs (which GitHub surfaces as issues), caps at cfg.max_issues,
    and returns a dict keyed by issue number.

    Args:
        repo: GitHub repository object
        cfg: Config object
        classify: classifier function from make_classifier

    Returns:
        Dict of {issue_number: serialized_issue_dict}
    """
    records: dict[int, dict] = {}
    log(f"[issues] collecting up to {cfg.max_issues} issues (state={cfg.issues_state})...")
    for issue in repo.get_issues(state=cfg.issues_state):
        if len(records) >= cfg.max_issues:
            break
        if issue.pull_request is not None:
            continue  # GitHub returns PRs from the issues endpoint; skip them
        records[issue.number] = _collect_one_issue(repo, issue, cfg, classify, is_seed=False)
        log(f"[issues] {len(records)}/{cfg.max_issues}  #{issue.number} {_short(issue.title)}")
    log(f"[issues] done: collected {len(records)} issues")
    return records


def collect_prs(repo, cfg, classify) -> dict[int, dict]:
    """Iterate and collect PRs from the repo.

    Caps at cfg.max_prs and returns a dict keyed by PR number.

    Args:
        repo: GitHub repository object
        cfg: Config object
        classify: classifier function from make_classifier

    Returns:
        Dict of {pr_number: serialized_pr_dict}
    """
    records: dict[int, dict] = {}
    log(f"[prs] collecting up to {cfg.max_prs} pull requests (state={cfg.prs_state})...")
    for pr in repo.get_pulls(state=cfg.prs_state):
        if len(records) >= cfg.max_prs:
            break
        records[pr.number] = _collect_one_pr(repo, pr, cfg, classify, is_seed=False)
        log(f"[prs] {len(records)}/{cfg.max_prs}  #{pr.number} {_short(pr.title)}")
    log(f"[prs] done: collected {len(records)} pull requests")
    return records


NEIGHBORHOOD_HARD_CAP = 200


def collect_neighborhood(repo, cfg, classify, issues: dict[int, dict],
                         prs: dict[int, dict]) -> None:
    """Breadth-first crawl from cfg.seed_issues, mutating issues/prs in place.

    Follows the spec §5 pseudocode: loop `neighborhood_depth` times, fetching the
    current frontier each pass and deduping by number against what's already collected.

    Args:
        repo: GitHub repository object
        cfg: Config object
        classify: classifier function from make_classifier
        issues: dict to mutate with collected issues (keyed by number)
        prs: dict to mutate with collected PRs (keyed by number)
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

    if seeds:
        log(f"[neighborhood] crawling from seeds {sorted(seeds)} "
            f"(depth={cfg.neighborhood_depth})...")

    for hop in range(cfg.neighborhood_depth):
        next_frontier: set[int] = set()
        for number in sorted(frontier):
            if number in collected:
                continue
            if fetches >= NEIGHBORHOOD_HARD_CAP:
                log(f"[neighborhood] WARNING: hard cap {NEIGHBORHOOD_HARD_CAP} reached; "
                    f"stopping crawl")
                return
            try:
                probe = call_with_retry(lambda n=number: repo.get_issue(n))
            except GithubException:
                log(f"[neighborhood] hop {hop + 1}: #{number} unresolved, skipping")
                collected.add(number)
                continue
            fetches += 1
            is_seed = number in seeds
            if probe.pull_request is not None:
                pr = call_with_retry(lambda n=number: repo.get_pull(n))
                record = _collect_one_pr(repo, pr, cfg, classify, is_seed=is_seed)
                prs[number] = record
                next_frontier |= set(record["linked_issue_numbers"])
                log(f"[neighborhood] hop {hop + 1}: +pr #{number} {_short(pr.title)} "
                    f"({fetches} fetched)")
            else:
                record = _collect_one_issue(repo, probe, cfg, classify, is_seed=is_seed)
                issues[number] = record
                next_frontier |= set(record["linked_pr_numbers"])
                next_frontier |= set(record["referenced_issue_numbers"])
                log(f"[neighborhood] hop {hop + 1}: +issue #{number} {_short(probe.title)} "
                    f"({fetches} fetched)")
            collected.add(number)
        frontier = next_frontier - collected


def build_client(token: str) -> Github:
    """Build a GitHub API client from a token.

    Args:
        token: Personal access token or similar (plain text)

    Returns:
        Github instance with token auth
    """
    return Github(auth=Auth.Token(token))


def _now_iso() -> str:
    """Current UTC time as ISO-8601 string.

    Returns:
        Formatted string: YYYY-MM-DDTHH:MM:SSZ
    """
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def main(argv: list[str] | None = None) -> int:
    """Orchestrate the full collection: parse, authenticate, collect, write.

    Exit codes:
        0: success (all records written, manifest written)
        2: missing or empty token
        3: repo not found or inaccessible (403/404)
        1: other fatal error (unrecoverable rate limit, network, etc.)

    Args:
        argv: command-line arguments (default: sys.argv[1:])

    Returns:
        Exit code
    """
    cfg = parse_args(argv)

    repo_dir = Path(cfg.out) / cfg.owner / cfg.repo
    log(f"=== GitHub collector: {cfg.owner}/{cfg.repo} -> {repo_dir} ===")

    token = os.environ.get(cfg.token_env, "").strip()
    if not token:
        log(f"ERROR: build-time token env '{cfg.token_env}' is missing or empty")
        return 2

    log("authenticating with GitHub...")
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
    log(f"authenticated; {cfg.owner}/{cfg.repo} is accessible")

    if cfg.clean and repo_dir.exists():
        log(f"cleaning existing snapshot at {repo_dir}")
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

    log(f"writing {len(issues)} issues + {len(prs)} prs to {repo_dir}...")
    for record in issues.values():
        write_record(repo_dir, "issues", record)
    for record in prs.values():
        write_record(repo_dir, "prs", record)

    write_manifest(repo_dir, cfg,
                   counts={"issues": len(issues), "prs": len(prs)},
                   seeds=cfg.seed_issues,
                   collected_at=_now_iso())
    log(f"=== done: {len(issues)} issues, {len(prs)} prs collected ===")
    log(f"data saved to: {repo_dir.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
