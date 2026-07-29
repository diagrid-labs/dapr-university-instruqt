# Design: `supply-chain-auditor` Instruqt track

**Date:** 2026-07-29
**Status:** Approved (pending spec review)

## Summary

A new Dapr University Instruqt track that teaches durable execution and a
supply-chain security model using the **Supply Chain Auditor (LangGraph)** demo.
The learner runs a staged LangGraph pipeline — wrapped as a durable Dapr Workflow
— that audits a real Dependabot PR, then crashes it mid-run and watches it resume
from durable Redis state **without repeating the expensive Claude `analyze` call**.

The track definition lives in **this repo** (`dapr-university-instruqt`). The demo
application code lives in a **separate repo** and is used **as-is**.

## Fixed decisions

| Decision | Choice | Notes |
|---|---|---|
| Deliverable | Instruqt track definition only | Robot drift tests + any code changes live in the code repo (separate PR, author-owned). No `tests/challenge.robot` or CI workflow added in this repo. |
| Demo code source | `github.com/diagrid-labs/ai-agent-tracks-instruqt`, path `langgraph/supply_chain_auditor` | Cloned in challenge 1. Used **exactly as-is** (crash-and-resume already built in). Same repo the `ai-agents-deepagents` sibling clones. |
| LLM provider | Anthropic / Claude (`ANTHROPIC_API_KEY`) | `LLM_MODEL` default `claude-sonnet-4-6`. |
| GitHub data | Live GitHub, **dry-run** (never posts) | Optional read-only `GITHUB_TOKEN` for authenticated reads; a read-only token makes any post attempt 403 gracefully ("nothing was sent"). |
| Runtime | Local Dapr **1.18** sidecar (not Catalyst) | `DAPR_GRPC_ENDPOINT` / `DAPR_API_TOKEN` stay empty. |
| Sandbox host | **Reuse** the `ai-agents-deepagents` host/image | Python 3.12 + uv + docker + dapr + gh. `host: {{...}}` convention in `tabs.md`. |
| Demo PR | `dapr/dapr-agents#635` (`DEP_ECOSYSTEM=pip`) | Must resolve to a source repo so the `analyze` (LLM) branch runs. |
| Arc | 3 challenges | Security model is reading/framing, not a dedicated challenge. |

## Reference tracks

- **`ai-agents-deepagents`** (primary sibling) — Python, clones
  `ai-agent-tracks-instruqt`, crash-and-resume durability arc, reused host/image.
  Copy its `_setup/sandbox-setup.sh`, `tabs.md`, `notes.md`, and challenge-1
  `scripts/setup.sh` shape.
- **`ai-agents-maf`** — reference for an AI/secret track's `check.sh`/`solve.sh`
  key validation.

## How the demo works (as-is, no code changes)

Pipeline (`graph.py`): `START → gather_evidence → (analyze | finalize) → render_report → END`.
Only `analyze` calls Claude; every node is a checkpointed Dapr Workflow activity.

- **Stage ledger** (`ledger.py`, `audit-ledger.log` under `AUDIT_OUTPUT_DIR`,
  default `./audit-out`): each executed node appends one
  `timestamp\tstage\tdetail` line. On resume a completed stage replays from
  durable history and its body does **not** re-run, so it is not re-appended.
- **Armed crash** (`graph.py` `render_report`, line ~132):
  `if ledger.count() >= 2: os._exit(1)`. Ships **armed** — after
  `gather_evidence` and `analyze` have each recorded a line (count == 2), the
  process dies inside `render_report`, i.e. **after** the Claude call has
  completed and been checkpointed. The learner comments this line out to resume.
- **Deterministic resume** (`runtime.py`, `app.py`): the workflow runs under
  instance id `audit-<repo>-<pr>-<package>`. `resume_or_invoke` reconnects to an
  in-flight instance and polls it to completion instead of scheduling a new run —
  Dapr re-dispatches the pending `render_report` node into the restarted process.

Two-run demo (from the demo README, verbatim commands):

```bash
# Run 1 (armed crash — no edit)
export AUDIT_OUTPUT_DIR="$PWD/audit-out"
ANTHROPIC_API_KEY=sk-ant-... PR_REPO=dapr/dapr-agents PR_NUMBER=635 DEP_ECOSYSTEM=pip \
  uv run dapr run --app-id supply-chain-auditor-langgraph --resources-path ./resources -- python app.py
cat "$AUDIT_OUTPUT_DIR/audit-ledger.log"   # 2 lines: gather_evidence, analyze

# Run 2 (comment out `if ledger.count() >= 2: os._exit(1)` in graph.py, re-run same command)
# → resumes, runs only render_report, Completed, report printed
cat "$AUDIT_OUTPUT_DIR/audit-ledger.log"   # 3 lines: +render_report, analyze NOT repeated
```

Reset for a fresh run: `docker exec dapr_redis redis-cli flushall` **and**
`rm -f "$AUDIT_OUTPUT_DIR/audit-ledger.log"` (stale ledger lines otherwise trip
the `count() >= 2` gate).

## The security model (reading — woven into ch1 & ch2)

1. **Deterministic heuristics first, no LLM** (`auditor_core/redflags.py`):
   install hooks, download-then-exec, obfuscation, raw-IP egress, credential
   access, CI-workflow edits, binary blobs, plus evidence flags. A prompt-injected
   diff can't suppress them.
2. **LLM grounds its judgement in nonce-tagged UNTRUSTED evidence** — it can only
   *raise* risk, never lower it.
3. **Reconcile enforces a floor** (`auditor_core/reconcile.py`):
   `final_score = max(llm_score, heuristic_floor)`. A CRITICAL heuristic pins
   FAIL/BLOCK regardless of the model. "Could not verify" never PASSes.

Not shown as a live run (the malicious case can't be reliably reproduced against a
live PR). Mentioned as reading, with an optional pointer to
`uv run pytest tests/test_reconcile.py` for the curious (the fixture proves a
`postinstall` hook + "docs only" changelog yields FAIL/block via `SC-INSTALL-HOOK`).

## Challenge arc (3 challenges, ~22 min)

### 1 · Set up & meet the auditor (`1-setup`, ~6 min)
- `_setup/sandbox-setup.sh`: install Dapr CLI, `docker login`,
  `dapr init --runtime-version <1.18.x>`, verify the `dapr_redis`/placement/
  scheduler/zipkin containers, install `uv`.
- `scripts/setup.sh`: `git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git`,
  `cd ai-agent-tracks-instruqt/langgraph/supply_chain_auditor`, `cp .env.template .env`.
- `assignment.md`: frame the supply-chain-attack problem and the staged pipeline
  diagram + security-model overview (reading). Steps: verify `dapr -v`; open the
  Editor `.env` and paste `ANTHROPIC_API_KEY` (note optional read-only
  `GITHUB_TOKEN`); `uv sync`. Check gate.
- `scripts/check.sh`: fail until `.env` exists and `ANTHROPIC_API_KEY` is
  non-empty (pattern from `ai-agents-maf`, adapted to the Anthropic key).
- `scripts/solve.sh`: write a placeholder key into `.env` so check passes.

### 2 · Run the durable pipeline & crash it (`2-run-and-crash`, ~8 min)
- `assignment.md`: `export AUDIT_OUTPUT_DIR="$PWD/audit-out"`, run the **armed**
  workflow against `dapr/dapr-agents#635` (no edit). Watch `gather_evidence →
  analyze` (the single Claude call) execute as Dapr activities, then the process
  die inside `render_report` (non-zero exit). Inspect the ledger (2 lines) and the
  checkpointed Redis keys that survived the crash
  (`docker exec dapr_redis redis-cli keys "*"`). Explain: only `analyze` hits the
  LLM; each node is a checkpointed activity; the crash lands *after* the expensive
  call. Reading: what the heuristic floor / guardrail mean for the verdict.
- No check/solve (a run-only challenge, like the deepagents sibling's middle
  challenges).

### 3 · Resume: durability proven (`3-resume`, ~8 min)
- `assignment.md`: comment out the one crash line in `graph.py`'s `render_report`
  (Editor), re-run the **exact same command**. Watch it reconnect to the in-flight
  instance ("resuming by polling"), replay `gather_evidence + analyze` from history
  (**no re-fetch, no second Claude call**), run only `render_report` → Completed,
  read the printed dry-run report. Verify: ledger = 3 lines, `analyze` once,
  visible timestamp gap. Reset instructions (`flushall` + `rm` ledger). Wrap-up +
  feedback step + further-learning links (Discord, blog, other tracks — copy the
  deepagents ch4 closing block).
- No check/solve.

## Files produced (in this repo, under `supply-chain-auditor/`)

```
supply-chain-auditor/
  README.md                      # Instruqt track config (Name, Url, Teaser, Time limit, Description, timeouts)
  website-description.md         # marketing copy for the Dapr University site
  _setup/
    sandbox-setup.sh             # per-launch: dapr init 1.18, uv, docker login, redis check
  1-setup/
    assignment.md  notes.md  tabs.md
    scripts/{setup.sh, check.sh, solve.sh}
  2-run-and-crash/
    assignment.md  notes.md  tabs.md
  3-resume/
    assignment.md  notes.md  tabs.md
```

- `tabs.md` (all challenges): Editor + Terminal, `host: {{...}}`, `path:
  ai-agent-tracks-instruqt/langgraph/supply_chain_auditor`.
- `notes.md`: ch1 uses the full intro opener; ch2/3 use the short "sandbox for
  this challenge is being prepared" opener (per the track-creation reference).
- Durations in intros sum < 30 min and match the README time limit (30).

## Out of scope (this repo / this task)

- `tests/challenge.robot` drift suites and `.github/workflows/test-*.yml` — live
  in the code repo, delivered in a separate author-owned PR.
- Any change to the demo application code — used as-is.
- A new `_setup` VM image — the deepagents host is reused.

## Pre-flight to verify before/at authoring time

1. `dapr/dapr-agents#635` still parses as a bump **and** resolves to a source repo
   (so `analyze`/LLM branch runs, not `finalize`). If it drifts, pick another
   real single-bump Dependabot PR with a resolvable upstream.
2. Exact Dapr **1.18** patch to pin in `dapr init --runtime-version`.
3. `claude-sonnet-4-6` reachable with the learner's key; otherwise document an
   `LLM_MODEL` override in `.env`.
4. `uv sync` + a full two-run demo completes within the sandbox time budget.
5. Confirm the reused deepagents host string once the track is imported to
   Instruqt (the `{{...}}` placeholder is resolved by the import tooling).

## Testing / verification approach

End-to-end drift testing (Robot Framework) is delivered in the code repo's PR, not
here. Within this task, verification is: (a) every `,run` command is valid against
the reused sandbox image; (b) `check.sh`/`solve.sh` for ch1 pass in the
solve→check order; (c) the two-run demo commands match the demo README exactly.
