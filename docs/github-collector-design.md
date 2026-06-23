# Spec — GitHub Data Collector (`collect_github_data.py`)

A build-time Python script that fetches a snapshot of a GitHub repository's issues and pull
requests and writes them to local JSON files. The snapshot is baked into the sandbox VM image so that the University tracks (see [`github-agent-tracks-ideas.md`](./github-agent-tracks-ideas.md)) read GitHub data **locally at runtime** — no `gh` CLI, no token, no network calls in the running sandbox.

This document is the spec for the collector and, equally importantly, **the JSON contract** that the runtime readers (.NET `GitHubDataReader`, Python `github_data.py`) depend on.

---

## 1. Purpose & boundaries

| | |
| --- | --- |
| **Runs** | Once per repo, at **VM image creation** — invoked from each track's `_setup/image-definition.sh`, alongside the Ollama model pulls. |
| **Never runs** | At sandbox startup (`sandbox-setup.sh`) or at application runtime. |
| **Auth** | A build-time GitHub token, read from an environment variable (`GITHUB_TOKEN` by default). The token is present only during image build and is absent from the running sandbox. |
| **Access** | Read-only against the target repo via the GitHub REST API (PyGithub). |
| **Output** | Local JSON files under `data/<owner>/<repo>/`. This output is the contract; the readers never call GitHub. |
| **Location** | `tools/github-collector/` at the repository root, shared by all tracks. Each track's `image-definition.sh` invokes it. |

### Non-goals

- No runtime/live GitHub access (explicitly rejected — see the tracks doc "Alternatives").
- No write access to GitHub (no labels, comments, or status changes).
- No summarization or truncation-for-context of issue/PR text beyond the raw-size cap below;
  shaping content to the model's context window is the **reader's** job at runtime.
- No incremental/delta sync. Each run produces a full snapshot for the repo (see `--clean`).

---

## 2. CLI interface

The collector is configured entirely by command-line arguments and run **once per repository**.
Multiple repositories = multiple invocations (one per repo in `image-definition.sh`).

```bash
# Track 1 — PR digest: a batch of open PRs with files/diffs
python collect_github_data.py --owner dapr --repo dapr \
  --max-prs 50 --max-issues 100

# Track 5 — deep investigation: seed issues + depth-1 neighborhood
python collect_github_data.py --owner dapr --repo dapr \
  --seed-issue 1234 --seed-issue 5678 --neighborhood-depth 1
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `--owner` | *(required)* | Repository owner / org. |
| `--repo` | *(required)* | Repository name. |
| `--out` | `./data` | Output root directory. |
| `--issues-state` | `open` | `open` \| `closed` \| `all`. |
| `--max-issues` | `100` | Maximum issues to collect (after filtering out PRs). |
| `--prs-state` | `open` | `open` \| `closed` \| `all`. |
| `--max-prs` | `50` | Maximum pull requests to collect. |
| `--include-pr-files` / `--no-pr-files` | on | Fetch each PR's changed files + patch. |
| `--include-comments` / `--no-comments` | on | Fetch issue/PR comments. |
| `--max-comments` | `50` | Cap comments stored per item (most recent kept). |
| `--max-patch-bytes` | `20000` | Per-file patch byte cap; larger patches are truncated and flagged `patch_truncated: true`. Keeps large-repo snapshots a reasonable size. |
| `--seed-issue` | *(none, repeatable)* | Neighborhood root issue number(s) for Track 5. |
| `--neighborhood-depth` | `1` | How many link-hops to follow from each seed. `0` disables crawling even if seeds are given. |
| `--token-env` | `GITHUB_TOKEN` | Name of the env var holding the build-time token. |
| `--clean` / `--no-clean` | clean | Wipe `data/<owner>/<repo>/` before writing, so each run is a clean, deterministic, re-runnable snapshot. |

**Exit codes:** `0` success; `2` missing/empty token; `3` repo not found / not accessible (404/403
on the repo itself); `1` any other fatal error (unrecoverable rate limit, network). Per-item
failures do **not** change the exit code (see §6).

---

## 3. Output layout

```
data/
  <owner>/
    <repo>/
      manifest.json
      issues/
        <number>.json
        ...
      prs/
        <number>.json
        ...
```

- One subtree per repo keeps multi-repo collection isolated; a reader is pointed at a single
  `data/<owner>/<repo>/` directory.
- Files are named by entity number (`issues/1234.json`, `prs/5678.json`) so the readers can do a
  direct `get_issue(number)` / `GetPullRequestFiles(number)` lookup without scanning.
- Neighborhood-crawled issues/PRs (Track 5) land in the **same** `issues/`/`prs/` directories,
  deduped by number, so the runtime "search related issues" tool simply queries the local set.

### `manifest.json`

```json
{
  "schema_version": 1,
  "owner": "dapr",
  "repo": "dapr",
  "collected_at": "2026-06-23T10:15:00Z",
  "source": "github-rest-api",
  "params": {
    "issues_state": "open", "max_issues": 100,
    "prs_state": "open", "max_prs": 50,
    "include_pr_files": true, "include_comments": true,
    "max_comments": 50, "max_patch_bytes": 20000,
    "neighborhood_depth": 1
  },
  "seed_issues": [1234, 5678],
  "counts": { "issues": 100, "prs": 50 }
}
```

`schema_version` lets readers fail fast if the on-disk format drifts from what they expect.

---

## 4. JSON contract (read by the runtime readers)

These shapes are stable; the readers in every track depend on them. Adding fields is backward
compatible; renaming/removing fields is a `schema_version` bump.

### Issue record — `issues/<number>.json`

```json
{
  "type": "issue",
  "number": 1234,
  "title": "Sidecar crashes on startup with custom config",
  "state": "open",
  "body": "When I set ...",
  "labels": ["bug", "good first issue"],
  "user": "octocat",
  "created_at": "2026-06-01T09:00:00Z",
  "updated_at": "2026-06-20T14:30:00Z",
  "comments": [
    { "user": "maintainer", "body": "Can you share logs?", "created_at": "2026-06-02T08:00:00Z" }
  ],
  "linked_pr_numbers": [5678],
  "referenced_issue_numbers": [1111, 2222],
  "html_url": "https://github.com/dapr/dapr/issues/1234",
  "is_seed": true,
  "partial": false
}
```

### Pull request record — `prs/<number>.json`

```json
{
  "type": "pr",
  "number": 5678,
  "title": "Fix sidecar startup race",
  "state": "open",
  "body": "Closes #1234 ...",
  "labels": ["area/runtime"],
  "user": "contributor",
  "created_at": "2026-06-10T11:00:00Z",
  "updated_at": "2026-06-21T16:00:00Z",
  "additions": 42,
  "deletions": 7,
  "changed_files": 3,
  "files": [
    {
      "filename": "pkg/runtime/runtime.go",
      "status": "modified",
      "additions": 30,
      "deletions": 5,
      "patch": "@@ -1,4 +1,4 @@ ...",
      "patch_truncated": false
    }
  ],
  "linked_issue_numbers": [1234],
  "comments": [],
  "html_url": "https://github.com/dapr/dapr/pull/5678",
  "is_seed": false,
  "partial": false
}
```

**Field notes**

- `linked_pr_numbers` / `referenced_issue_numbers` / `linked_issue_numbers` come from reference
  extraction (§5). They may be empty.
- `files` is present only when `--include-pr-files` is on; `patch` is `null` and
  `patch_truncated: true` when a patch exceeds `--max-patch-bytes`.
- `comments` is capped by `--max-comments` (most recent retained) and empty when
  `--no-comments`.
- `is_seed` is `true` only for issues explicitly passed as `--seed-issue`.
- `partial` is `true` when a sub-fetch for that record failed and was skipped (see §6).

---

## 5. Reference extraction & the Track 5 neighborhood

Reference numbers populate the `*_numbers` fields and drive neighborhood crawling.

**Extraction sources, per entity:**
1. Regex over `body` and each comment: `#(\d+)` and close-keywords
   (`close[sd]? #N`, `fix(e[sd])? #N`, `resolve[sd]? #N`).
2. GitHub cross-references via the timeline API (`issue.get_timeline()` →
   `cross-referenced` events) where available.

Each extracted number is classified as **issue** or **PR** by looking it up through the API (GitHub surfaces PRs as issues, so the `pull_request` attribute disambiguates). Numbers that don't resolve are dropped.

**Neighborhood crawl (only when `--seed-issue` is given and `--neighborhood-depth > 0`):**

```
frontier = {seed issues}
collected = {}
for hop in 1..depth:
    for each item in frontier not already collected:
        fetch + serialize it
        record its references
    frontier = (all newly referenced issues/PRs) - collected
```

- Crawled items are written into the same `issues/`/`prs/` dirs, deduped by number.
- The crawl is bounded by `--neighborhood-depth` and by an internal hard cap on total
  neighborhood fetches (to protect build time); reaching the cap logs a warning and stops
  expanding — it does not fail the build.
- Seeds count toward `seed_issues` in the manifest and are flagged `is_seed: true`.

The flat collection (`--max-issues` / `--max-prs`) and the neighborhood crawl are additive: a run can do both (e.g. recent open issues **and** a seed neighborhood) and the union is deduped.

---

## 6. Robustness & error handling

- **Pagination:** use PyGithub's lazy paginated iterators, stopping at the `--max-*` caps so we never page the entire history of a large repo.
- **Primary rate limit:** on `RateLimitExceededException`, sleep until the reset time reported by the API, then resume.
- **Secondary / abuse limits:** on 403 secondary-limit responses, retry with exponential backoff up to a fixed retry cap; exhausting the cap is a fatal error (exit `1`) so a broken build is loud, not silently partial.
- **Idempotent & re-runnable:** with `--clean` (default) each run wipes and rewrites the repo's subtree, producing a deterministic snapshot regardless of prior state.
- **Per-item fault tolerance:** a failure fetching one record's sub-resource (a comment page, a file list, a referenced item) logs a warning, marks that record `partial: true`, and continues. Only **systemic** failures abort: missing token (`2`), repo inaccessible (`3`), unrecoverable rate limit/network (`1`).
- **Logging:** human-readable progress to stderr (repo, counts, retries, truncations, partials) so an image build's logs show exactly what was captured.

---

## 7. Module structure

A single module, `tools/github-collector/collect_github_data.py`, with focused, independently
testable functions:

| Function | Responsibility |
| --- | --- |
| `parse_args()` | Build and parse the CLI (argparse). |
| `build_client(token)` | Construct the PyGithub `Github` client. |
| `collect_issues(repo, cfg)` | Flat issue collection (filters out PRs), capped. |
| `collect_prs(repo, cfg)` | Flat PR collection, with files/comments per flags. |
| `extract_references(text, timeline)` | Return referenced issue/PR numbers. |
| `collect_neighborhood(repo, seeds, depth, cfg)` | Breadth-first crawl from seeds. |
| `serialize_issue(...)` / `serialize_pr(...)` | Build the JSON contract records. |
| `write_record(out_dir, kind, record)` | Write one `<number>.json`. |
| `write_manifest(out_dir, cfg, counts, seeds)` | Write `manifest.json`. |
| `main()` | Orchestrate; map outcomes to exit codes. |

Network access is confined to `build_client` / `collect_*`; serialization and writing are pure, so
the contract can be unit-tested with a mocked client and asserted against fixtures.

### Dependencies

`tools/github-collector/pyproject.toml` pinning **PyGithub** (and nothing else runtime-relevant).
Python 3.12 (matches the image, per `image-definition.sh`).

---

## 8. Integration with the tracks

In each track's `_setup/image-definition.sh`, after the Ollama pulls, add the collection step using
the build-time token, e.g.:

```bash
# Collect the GitHub snapshot once, at image build time.
GITHUB_TOKEN="$BUILD_GITHUB_TOKEN" \
  python3 tools/github-collector/collect_github_data.py \
    --owner dapr --repo dapr --max-prs 50 --max-issues 100 \
    --out /opt/track-data
```

The runtime readers (`GitHubDataReader` / `github_data.py`) point at the resulting
`/<out>/<owner>/<repo>/` directory. With the snapshot baked into the image, the `gh` CLI install in`image-definition.sh` is no longer needed for data access and can be removed unless used elsewhere.

---

## 9. Open questions for build time

- **Token scope:** a fine-grained read-only token for public repos is sufficient; confirm the build pipeline can inject `GITHUB_TOKEN` as a build-only secret.
- **Snapshot size budget:** confirm per-track `--max-*` and `--max-patch-bytes` values keep the image acceptably small for the chosen repos (especially `kubernetes/kubernetes`).
- **Neighborhood hard cap:** pick the internal total-fetch cap for the Track 5 crawl so a deep seed can't explode build time.
- **Closed-state realism:** decide per track whether `closed`/`all` issues add realism (e.g. for duplicate detection in Track 3) or just bloat the snapshot.
