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
