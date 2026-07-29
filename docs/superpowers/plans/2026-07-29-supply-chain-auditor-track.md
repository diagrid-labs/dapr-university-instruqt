# Supply Chain Auditor Track Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author a 3-challenge Dapr University Instruqt track (`supply-chain-auditor`) that runs the LangGraph Supply Chain Auditor demo as a durable Dapr Workflow, then crashes and resumes it.

**Architecture:** Pure track-authoring — Markdown + shell files under a new `supply-chain-auditor/` directory in this repo. No application code is written here; the track clones the demo app from `diagrid-labs/ai-agent-tracks-instruqt` and drives it as-is. Reuses the `ai-agents-deepagents` sandbox host/image. Files mirror the `ai-agents-deepagents` and `ai-agents-maf` sibling tracks.

**Tech Stack:** Instruqt track Markdown (README/assignment/notes/tabs config format), Bash setup/check/solve scripts, Dapr 1.18 CLI, `uv`, Python demo app (Claude via Anthropic).

## Global Constraints

- **Deliverable is the track definition only.** No `tests/challenge.robot`, no `.github/workflows/test-*.yml`, no changes to the demo app code — those are handled in a separate author-owned PR in the code repo.
- **Demo app path (in the sandbox after clone):** `ai-agent-tracks-instruqt/langgraph/supply_chain_auditor`.
- **Sandbox host string in every `tabs.md`:** `{{...}}` (reused deepagents host; resolved by Instruqt import tooling).
- **LLM:** Anthropic/Claude. Secret var `ANTHROPIC_API_KEY`. `LLM_MODEL` default `claude-sonnet-4-6`.
- **All run inputs live in `.env`** (written by `1-setup/scripts/setup.sh`): `PR_REPO=dapr/dapr-agents`, `PR_NUMBER=635`, `DEP_ECOSYSTEM=pip` prefilled; learner fills only `ANTHROPIC_API_KEY`. Run command is a bare `python app.py` under `dapr run` — no inline env vars.
- **Runtime:** local Dapr **1.18** sidecar (not Catalyst). `DAPR_GRPC_ENDPOINT`/`DAPR_API_TOKEN` stay empty.
- **Ledger/report output dir:** default `./audit-out` (do not set `AUDIT_OUTPUT_DIR`).
- **Armed crash line** the learner toggles: `graph.py` `render_report`, `if ledger.count() >= 2: os._exit(1)`.
- **Challenge durations** stated in intros must sum < 30 and match the README time limit (30). Idle timeout 10 min, extra time 10 min.
- **notes.md openers:** challenge 1 = full intro opener; challenges 2–3 = short "sandbox for this challenge is being prepared" opener.
- **`,run` code fences** for commands the learner executes; `,nocopy` for expected-output/read-only blocks; plain ` ```bash ` or `,copy` where noted.

---

## File Structure

```
supply-chain-auditor/
  README.md                       # Instruqt track config
  website-description.md          # Dapr University site marketing copy
  _setup/
    sandbox-setup.sh              # per-launch env prep (Dapr 1.18, uv, redis check)
  1-setup/
    assignment.md  notes.md  tabs.md
    scripts/setup.sh  scripts/check.sh  scripts/solve.sh
  2-run-and-crash/
    assignment.md  notes.md  tabs.md
  3-resume/
    assignment.md  notes.md  tabs.md
```

`tabs.md` is identical in all three challenges. `notes.md` differs (full vs short opener). Only challenge 1 has `scripts/`.

---

## Task 1: Track scaffold — config, marketing copy, sandbox setup

**Files:**
- Create: `supply-chain-auditor/README.md`
- Create: `supply-chain-auditor/website-description.md`
- Create: `supply-chain-auditor/_setup/sandbox-setup.sh`

**Interfaces:**
- Produces: the track `Url` = `supply-chain-auditor`; the sandbox guarantees relied on by all challenges — Dapr 1.18 initialized (containers `dapr_placement`, `dapr_scheduler`, `dapr_redis`, `dapr_zipkin` running), `uv` on PATH, `docker` logged in. The repo is **not** cloned here (challenge 1's `setup.sh` does that).

- [ ] **Step 1: Create `supply-chain-auditor/README.md`**

```markdown
# Name

Audit dependency bumps for supply-chain attacks with Dapr Workflow

## Url

supply-chain-auditor

## Teaser

Run an AI agent that audits a real Dependabot PR for a supply-chain attack — where a dependency's changelog says "docs only" but the code slips in something malicious. It runs as a durable Dapr Workflow, so when you crash it mid-audit it resumes from durable state without repeating the expensive Claude analysis.

Languages: Python. Duration: 30 min. Requires an Anthropic API key.

## Time limit (minutes)

30

## Description

Dependabot opens a pull request; its changelog says "documentation only". But does the actual source diff match that claim? The classic supply-chain attack hides malicious code — an install hook, a credential grab, an obfuscated payload — inside an update whose notes read as innocent. In this self-paced track you'll run the **Supply Chain Auditor**, an AI agent that checks a dependency bump's upstream release notes against its real source changes, and see how **Dapr Workflow** makes that audit durable.

You'll work with a staged [LangGraph](https://www.langchain.com/langgraph) pipeline — `gather_evidence → analyze → render_report` — where only the `analyze` node calls Claude, and every node runs as a checkpointed Dapr Workflow activity.

In this self-paced track, you'll learn:
- How the auditor combines deterministic red-flag heuristics with an LLM judgement, and why the heuristics set a floor the model can only raise.
- Why durable execution matters when one node in a pipeline makes an expensive, non-idempotent LLM call.
- How each pipeline node becomes a Dapr Workflow activity checkpointed to a Redis state store.
- How a real mid-run crash resumes from durable state — replaying the completed `gather_evidence` and `analyze` steps from history instead of re-fetching from GitHub or calling Claude again.

You'll probably need around 22 minutes to complete the 3 challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
```

- [ ] **Step 2: Create `supply-chain-auditor/website-description.md`**

```markdown
# Audit dependency bumps for supply-chain attacks with Dapr Workflow

A dependency update's changelog is attacker-controllable text. When it says "documentation only" but the source diff adds an install hook that curls a script and pipes it to a shell, you have a supply-chain attack. In this hands-on track you'll run an AI agent that catches exactly that — and see how Dapr Workflow makes the audit durable enough to survive a crash.

## What you'll build

You'll run the **Supply Chain Auditor** — a staged LangGraph pipeline that audits a real Dependabot pull request. It resolves the bumped package to its upstream repo, fetches the release notes and the actual source diff, runs deterministic red-flag heuristics, and asks Claude to judge whether the narrative matches the code. Only the `analyze` node calls the LLM; every node runs as a checkpointed Dapr Workflow activity. Then you'll crash the process mid-audit and watch it resume without repeating the Claude call.

## What you'll learn

- How a security-focused agent grounds an LLM in untrusted, nonce-tagged evidence and enforces a deterministic heuristic floor the model can only raise.
- Why durable execution is essential when a pipeline node makes an expensive, non-idempotent LLM call.
- How Dapr Workflow checkpoints each pipeline node so completed work replays from history, not recomputation.
- How a real process crash resumes from durable Redis state without re-fetching from GitHub or re-invoking Claude.

## Supported language

Python

## Prerequisites

Familiarity with Python and basic command-line tooling is recommended. The sandbox comes preconfigured with Docker, Python, `uv`, and Dapr. You'll need your own Anthropic API key (Claude) to run the `analyze` step.
```

- [ ] **Step 3: Create `supply-chain-auditor/_setup/sandbox-setup.sh`**

```bash
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
docker login -u ${DockerUSER} -p ${DockerPAT}
dapr init --runtime-version 1.18.0
dapr -v

if [ -n "$(docker ps -f "name=dapr_placement" -f "status=running" -q )" ] && [ -n "$(docker ps -f "name=dapr_scheduler" -f "status=running" -q )" ] && [ -n "$(docker ps -f "name=dapr_redis" -f "status=running" -q )"  ] && [ -n "$(docker ps -f "name=dapr_zipkin" -f "status=running" -q )" ];
then
    echo "The Dapr containers are running! 👍"
else
    dapr uninstall
    dapr init --runtime-version 1.18.0
fi

wget -qO- https://astral.sh/uv/install.sh | sh
```

- [ ] **Step 4: Verify the shell script parses**

Run: `bash -n supply-chain-auditor/_setup/sandbox-setup.sh && echo OK`
Expected: `OK` (no syntax errors).

- [ ] **Step 5: Confirm the Dapr 1.18 pin and reused host**

Run: `grep -n "runtime-version" supply-chain-auditor/_setup/sandbox-setup.sh`
Expected: two lines both showing `1.18.0`. (Pre-flight: bump `1.18.0` to the exact latest 1.18 patch you want to pin before publishing.)

- [ ] **Step 6: Commit**

```bash
git add supply-chain-auditor/README.md supply-chain-auditor/website-description.md supply-chain-auditor/_setup/sandbox-setup.sh
git commit -m "Add supply-chain-auditor track scaffold (config, marketing, sandbox setup)"
```

---

## Task 2: Challenge 1 — Set up & meet the auditor

**Files:**
- Create: `supply-chain-auditor/1-setup/assignment.md`
- Create: `supply-chain-auditor/1-setup/notes.md`
- Create: `supply-chain-auditor/1-setup/tabs.md`
- Create: `supply-chain-auditor/1-setup/scripts/setup.sh`
- Create: `supply-chain-auditor/1-setup/scripts/check.sh`
- Create: `supply-chain-auditor/1-setup/scripts/solve.sh`

**Interfaces:**
- Consumes: the sandbox guarantees from Task 1 (Dapr 1.18, `uv`, docker login).
- Produces: a cloned repo at `ai-agent-tracks-instruqt/langgraph/supply_chain_auditor` with a `.env` containing prefilled `PR_REPO`/`PR_NUMBER`/`DEP_ECOSYSTEM` and a `your_key_here` placeholder for `ANTHROPIC_API_KEY`. Challenges 2–3 rely on this working directory + `.env` existing.

- [ ] **Step 1: Create `supply-chain-auditor/1-setup/scripts/setup.sh`**

```bash
git clone https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git

cat > ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env << 'EOF'
ANTHROPIC_API_KEY=your_key_here
GITHUB_TOKEN=
PR_REPO=dapr/dapr-agents
PR_NUMBER=635
DEP_ECOSYSTEM=pip
LLM_MODEL=claude-sonnet-4-6
LOG_LEVEL=INFO
EOF
```

- [ ] **Step 2: Create `supply-chain-auditor/1-setup/scripts/check.sh`**

```bash
ENV_FILE="ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env"

if [ ! -f "$ENV_FILE" ]; then
    fail-message "No .env file found at $ENV_FILE. Make sure the sandbox finished setting up."
elif grep -qE '^ANTHROPIC_API_KEY=your_key_here[[:space:]]*$' "$ENV_FILE"; then
    fail-message "ANTHROPIC_API_KEY is still the placeholder. Replace 'your_key_here' with your real Anthropic API key in the .env file, then click Check again."
elif ! grep -qE '^ANTHROPIC_API_KEY=.+' "$ENV_FILE"; then
    fail-message "ANTHROPIC_API_KEY is empty in .env. Paste your key after the '=' sign, then click Check again."
fi
```

- [ ] **Step 3: Create `supply-chain-auditor/1-setup/scripts/solve.sh`**

```bash
ENV_FILE="ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env"
sed -i 's/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=sk-ant-dummy-key-for-solve/' "$ENV_FILE"
```

- [ ] **Step 4: Create `supply-chain-auditor/1-setup/tabs.md`**

```markdown
# Tab configuration

## Editor

type: code editor
host: {{...}}
path: ai-agent-tracks-instruqt/langgraph/supply_chain_auditor

## Terminal

type: terminal
host: {{...}}
path: ai-agent-tracks-instruqt/langgraph/supply_chain_auditor
```

- [ ] **Step 5: Create `supply-chain-auditor/1-setup/notes.md`** (full intro opener)

```markdown
Click the *Start* button to setup the sandbox environment for this training, this may take up to 2 minutes. Once the environment is ready, click the *Start* button again.

There are 3 challenges to complete, each takes about 6-8 minutes. If your session is idle for more than 10 minutes, the session will stop and you'll need to restart the track.

---

### What you'll learn in this challenge

- What the Supply Chain Auditor does and the attack it defends against
- How the staged LangGraph pipeline is wired, and which node calls the LLM
- How the deterministic heuristics set a floor the model can only raise
- How to confirm your sandbox is ready and add your Anthropic API key
```

- [ ] **Step 6: Create `supply-chain-auditor/1-setup/assignment.md`**

````markdown
Welcome to **Audit dependency bumps for supply-chain attacks with Dapr Workflow**. In this track you'll run the **Supply Chain Auditor** — an AI agent that checks whether a Dependabot dependency bump's upstream release notes match its actual source code changes — then make that audit survive a crash with Dapr Workflow.

In this first challenge you'll set up the sandbox and add your Anthropic API key. This challenge takes about 6 minutes to complete.

## The attack

A dependency update's changelog is written by whoever published the release — including an attacker. The classic supply-chain attack ships malicious code (an install hook, a credential grab, an obfuscated payload) inside an update whose notes say something innocent like "documentation only". If you trust the changelog, you merge the attack.

## The auditor

The Supply Chain Auditor is a staged [LangGraph](https://www.langchain.com/langgraph) pipeline:

```text,nocopy
START → gather_evidence → ┬─ analyze  ─┐→ render_report → END
                          └─ finalize ─┘
        (resolve repo,      (Claude judges    (Markdown report)
         fetch notes+diff,    notes vs diff,
         run heuristics)      reconciled)
```

- **`gather_evidence`** resolves the bumped package to its upstream GitHub repo, fetches the release notes and the real source diff, and runs deterministic red-flag heuristics — no LLM.
- **`analyze`** is the only node that calls **Claude**. It grounds its judgement in the untrusted, nonce-tagged evidence and produces a structured verdict.
- **`render_report`** renders the verdict to a Markdown comment.

Every node runs as a durable **Dapr Workflow activity** — which is what makes the crash-and-resume in the next challenges possible.

## The security model

The auditor never lets the LLM talk it out of a red flag:

1. **Heuristics run first, without the LLM** (`auditor_core/redflags.py`): install hooks, download-then-exec, obfuscation, raw-IP egress, credential access, CI-workflow edits, binary blobs.
2. **The LLM can only raise risk**, never lower it. The changelog and diff are attacker-controllable, so they're wrapped in nonce-tagged `UNTRUSTED` blocks and the model is told to treat them as data, never instructions.
3. **Reconcile enforces a floor** (`auditor_core/reconcile.py`): `final_score = max(llm_score, heuristic_floor)`. A CRITICAL heuristic pins FAIL/BLOCK no matter what the model says.

## 1. Verify the sandbox

Use the **Terminal** to confirm the Dapr CLI and runtime are ready:

```bash,run
dapr -v
```

> [!NOTE]
> You should see both a **CLI version** and a **Runtime version**. If the Runtime version is blank, run `dapr init --runtime-version 1.18.0`. If you hit any other blocking issue during this track, send me [an email](mailto:marc@diagrid.io) and we'll figure it out together.

Confirm the Redis state store that backs the Dapr Workflow engine is running:

```bash,run
docker ps | grep dapr_redis
```

## 2. Add your Anthropic API key

The `analyze` node calls Claude, so you need an Anthropic API key. The `.env` file is already created with the PR to audit prefilled — you only need to add your key.

Open `.env` in the **Editor** and replace `your_key_here` with your real key:

```text,nocopy
ANTHROPIC_API_KEY=your_key_here
```

> [!NOTE]
> Get a key from https://console.anthropic.com/. The other values — `PR_REPO`, `PR_NUMBER`, `DEP_ECOSYSTEM` — are already filled in and point at a real Dependabot PR (`dapr/dapr-agents#635`). `GITHUB_TOKEN` is optional; without it the auditor reads GitHub unauthenticated and prints its report as a dry-run instead of posting it, which is what we want here.

## 3. Install dependencies

Use the **Terminal** to install the app's dependencies with `uv`:

```bash,run
uv sync
```

> [!IMPORTANT]
> Click the *Check* button to verify your Anthropic API key is set before continuing.

---

You've got a working sandbox, the auditor cloned, and your key in place. Next you'll run the audit as a durable Dapr Workflow — and crash it on purpose.
````

- [ ] **Step 7: Verify all three scripts parse**

Run: `for f in supply-chain-auditor/1-setup/scripts/*.sh; do bash -n "$f" && echo "OK $f"; done`
Expected: `OK` for setup.sh, check.sh, solve.sh.

- [ ] **Step 8: Simulate the solve→check pass locally**

Run:
```bash
tmp=$(mktemp -d); mkdir -p "$tmp/ai-agent-tracks-instruqt/langgraph/supply_chain_auditor"
( cd "$tmp" && printf 'ANTHROPIC_API_KEY=your_key_here\nPR_REPO=dapr/dapr-agents\n' > ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env
  # solve: swap placeholder for a dummy key
  sed -i 's/^ANTHROPIC_API_KEY=.*/ANTHROPIC_API_KEY=sk-ant-dummy-key-for-solve/' ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env
  # check logic (fail-message shimmed to echo+exit):
  fail-message() { echo "FAIL: $*"; exit 1; }
  ENV_FILE="ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env"
  if [ ! -f "$ENV_FILE" ]; then fail-message "no env";
  elif grep -qE '^ANTHROPIC_API_KEY=your_key_here[[:space:]]*$' "$ENV_FILE"; then fail-message "placeholder";
  elif ! grep -qE '^ANTHROPIC_API_KEY=.+' "$ENV_FILE"; then fail-message "empty"; fi
  echo "CHECK PASSED" )
rm -rf "$tmp"
```
Expected: `CHECK PASSED` (solve fills a real value, so check passes). Confirm that removing the solve `sed` line instead prints `FAIL: placeholder`.

- [ ] **Step 9: Commit**

```bash
git add supply-chain-auditor/1-setup
git commit -m "Add supply-chain-auditor challenge 1 (setup + key validation)"
```

---

## Task 3: Challenge 2 — Run the durable pipeline & crash it

**Files:**
- Create: `supply-chain-auditor/2-run-and-crash/assignment.md`
- Create: `supply-chain-auditor/2-run-and-crash/notes.md`
- Create: `supply-chain-auditor/2-run-and-crash/tabs.md`

**Interfaces:**
- Consumes: the cloned app + `.env` with a real key from Task 2.
- Produces: a crashed workflow instance `audit-dapr-dapr-agents-635-<pkg>` left **in-flight** in Redis, plus `audit-out/audit-ledger.log` with 2 lines (`gather_evidence`, `analyze`). Challenge 3 resumes exactly this instance.

- [ ] **Step 1: Create `supply-chain-auditor/2-run-and-crash/tabs.md`** (identical to challenge 1)

```markdown
# Tab configuration

## Editor

type: code editor
host: {{...}}
path: ai-agent-tracks-instruqt/langgraph/supply_chain_auditor

## Terminal

type: terminal
host: {{...}}
path: ai-agent-tracks-instruqt/langgraph/supply_chain_auditor
```

- [ ] **Step 2: Create `supply-chain-auditor/2-run-and-crash/notes.md`** (short opener)

```markdown
The sandbox for this challenge is being prepared, it should be ready within a few seconds. Once it's ready, click the *Start* button.

---

### What you'll learn in this challenge

- How to run the auditor as a durable Dapr Workflow
- Which pipeline node calls Claude, and why that call is the expensive one
- What it looks like when the process crashes mid-pipeline
- How to see the checkpointed workflow state that survived the crash in Redis
```

- [ ] **Step 3: Create `supply-chain-auditor/2-run-and-crash/assignment.md`**

````markdown
In this challenge you'll run the auditor against a real Dependabot PR as a durable Dapr Workflow — and it will crash on purpose partway through. This challenge takes about 8 minutes to complete.

## 1. Look at the crash line

The durability demo ships with a deliberate crash, **armed by default**. Open `graph.py` in the **Editor** and find it in the `render_report` node:

```python,nocopy
if ledger.count() >= 2: os._exit(1)     # ← comment out for the resume run
```

By the time `render_report` runs, `gather_evidence` and `analyze` have each recorded one line in a stage *ledger* (`audit-out/audit-ledger.log`) — so `ledger.count()` is 2 and the process dies **right after** the expensive Claude call has completed and been checkpointed. `os._exit(1)` kills the process immediately — no cleanup, like a pod eviction or an OOM kill.

> [!NOTE]
> Leave this line as-is for now. You'll comment it out in the next challenge to watch the workflow resume.

## 2. Run the audit

Use the **Terminal** to run the auditor. `dapr run` starts a Dapr sidecar and runs `python app.py` against it. All inputs (the PR to audit, your key) come from `.env`:

```bash,run
uv run dapr run --app-id supply-chain-auditor-langgraph --resources-path ./resources -- python app.py
```

Watch the terminal:

1. `gather_evidence` resolves the package, fetches the release notes and diff from GitHub, and runs the heuristics.
2. `analyze` calls **Claude** to judge the notes against the diff.
3. `render_report` starts — and the process **dies by itself**:

```text,nocopy
❌  The App process exited with error code: 1
```

That crash landed *after* the Claude call completed. Look at the ledger — it holds the two stages that ran before the crash:

```bash,run
cat audit-out/audit-ledger.log
```

You'll see a `gather_evidence` line and an `analyze` line, each with a timestamp.

## 3. See the state that survived

Even though the process died, Dapr checkpointed each completed node to Redis. Confirm the workflow instance is still there:

```bash,run
docker exec dapr_redis redis-cli keys "*audit-dapr-dapr-agents-635*"
```

You'll see keys for the workflow instance and its checkpointed activity results. This is exactly the state the next challenge resumes from — the completed `gather_evidence` and `analyze` results are saved, so they never have to run again.

## 4. How this works

1. Each LangGraph node (`gather_evidence`, `analyze`, `render_report`) is registered as a **Dapr Workflow activity**.
2. Before moving to the next node, Dapr checkpoints the previous node's result to the Redis state store (`resources/workflowstate.yaml`, `actorStateStore: "true"`).
3. `app.py` runs the workflow under a **deterministic instance ID** derived from the PR — `audit-dapr-dapr-agents-635-<package>` — so a later run can find this exact instance instead of starting a new one.
4. `os._exit(1)` killed the process after `analyze` was checkpointed but before `render_report` finished, leaving the instance **in-flight** in Redis.

---

The audit crashed before it could produce a report — but nothing that already ran was lost. In the final challenge you'll comment out the crash, re-run the same command, and watch Dapr resume the workflow without re-fetching from GitHub or calling Claude again.
````

- [ ] **Step 4: Verify the `,run` commands match the app**

Run: `grep -nE '```bash,run' supply-chain-auditor/2-run-and-crash/assignment.md`
Expected: exactly the three commands — `uv run dapr run ... python app.py`, `cat audit-out/audit-ledger.log`, `docker exec dapr_redis redis-cli keys "*audit-dapr-dapr-agents-635*"`. Cross-check the `dapr run` app-id/resources-path against the demo README and `agent.py` `RUNNER_NAME` (`supply-chain-auditor-langgraph`).

- [ ] **Step 5: Commit**

```bash
git add supply-chain-auditor/2-run-and-crash
git commit -m "Add supply-chain-auditor challenge 2 (run and crash)"
```

---

## Task 4: Challenge 3 — Resume: durability proven

**Files:**
- Create: `supply-chain-auditor/3-resume/assignment.md`
- Create: `supply-chain-auditor/3-resume/notes.md`
- Create: `supply-chain-auditor/3-resume/tabs.md`

**Interfaces:**
- Consumes: the in-flight workflow instance + 2-line ledger from Task 3.
- Produces: (terminal challenge) a completed workflow, a 3-line ledger (`analyze` not repeated), a printed dry-run report. No downstream tasks.

- [ ] **Step 1: Create `supply-chain-auditor/3-resume/tabs.md`** (identical to challenge 1)

```markdown
# Tab configuration

## Editor

type: code editor
host: {{...}}
path: ai-agent-tracks-instruqt/langgraph/supply_chain_auditor

## Terminal

type: terminal
host: {{...}}
path: ai-agent-tracks-instruqt/langgraph/supply_chain_auditor
```

- [ ] **Step 2: Create `supply-chain-auditor/3-resume/notes.md`** (short opener)

```markdown
The sandbox for this challenge is being prepared, it should be ready within a few seconds. Once it's ready, click the *Start* button.

---

### What you'll learn in this challenge

- How Dapr reconnects to an in-flight workflow instead of starting over
- How replay returns completed steps from history without re-running them
- How to prove the expensive Claude call ran exactly once across the crash
- How to reset the demo to run it again from scratch
```

- [ ] **Step 3: Create `supply-chain-auditor/3-resume/assignment.md`**

````markdown
The audit crashed in the last challenge, but Dapr checkpointed every completed step to Redis. In this final challenge you'll comment out the crash and re-run the exact same command — and watch the workflow resume instead of starting over. This challenge takes about 8 minutes to complete.

## 1. Disarm the crash

Open `graph.py` in the **Editor** and comment out the crash line in `render_report`:

```python,nocopy
# if ledger.count() >= 2: os._exit(1)     # ← comment out for the resume run
```

Save the file.

## 2. Re-run the exact same command

Use the **Terminal** to run the same command as before — the inputs still come from `.env`:

```bash,run
uv run dapr run --app-id supply-chain-auditor-langgraph --resources-path ./resources -- python app.py
```

Watch the terminal closely. This time `app.py` derives the same deterministic instance ID, finds the instance **still in flight** in Redis, and polls it to completion instead of scheduling a new run. You'll see a log line like:

```text,nocopy
Workflow audit-dapr-dapr-agents-635-... in flight (WorkflowStatus.RUNNING) — resuming by polling
```

Dapr replays `gather_evidence` and `analyze` from durable history — returning their saved results **without re-executing them** — and runs only `render_report`. The workflow reaches **Completed** and the Markdown report is printed (a dry-run, since no `GITHUB_TOKEN` is set).

## 3. Prove the analyze call ran exactly once

Look at the ledger again:

```bash,run
cat audit-out/audit-ledger.log
```

You should see **exactly three lines** — `gather_evidence`, `analyze`, `render_report`, each once:

- The `analyze` line has the timestamp from the **first** run (before the crash). It was **not** written again on resume — proof the Claude call ran exactly once.
- There's a visible **time gap** before the `render_report` line: the wall-clock cost of the crash and restart, inside one logical workflow run.

That's the whole point: a crash cost a restart, not the work — and not a second Claude call.

## 4. How this works

1. On the first run, `app.py` found no instance under `audit-dapr-dapr-agents-635-<pkg>` and scheduled a fresh workflow.
2. `os._exit(1)` killed the process after `analyze` was checkpointed, leaving the instance in-flight.
3. On this run, `app.py` derived the same ID, found the instance still `RUNNING`, and polled it to completion (`resume_or_invoke` in `runtime.py`) instead of starting over.
4. Dapr rehydrated the instance, replayed the checkpointed `gather_evidence` and `analyze` results from history, and resumed at `render_report`. Neither the GitHub fetch nor the Claude call was repeated.

## 5. Reset for a fresh run (optional)

To run the whole demo again from scratch, purge the workflow state **and** the ledger, then re-arm the crash by un-commenting the line in `graph.py`:

```bash,run
docker exec dapr_redis redis-cli flushall
rm -f audit-out/audit-ledger.log
```

> [!NOTE]
> The ledger must be removed too — stale lines would push `ledger.count()` to 2 and trip the crash gate before the pipeline even reaches `render_report`.

## Recap

You crashed a running audit on purpose and watched it recover without losing work:

- Each pipeline node is a **checkpointed Dapr Workflow activity**; its result is written to durable Redis state the moment it completes.
- `os._exit(1)` killed the process hard after the expensive `analyze` (Claude) call had been checkpointed.
- On restart, `app.py` reconnected to the **same workflow instance by its deterministic ID**, and Dapr **replayed history from the checkpoint store** — returning saved results without re-executing them — and resumed at `render_report`. Claude was never called twice.
- The audit completed and produced a full report, even though the process that started it had died.

## Feedback and further learning

Congratulations! 🎉 You've completed the *Audit dependency bumps for supply-chain attacks with Dapr Workflow* learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving it.

We have more ways for you to learn and share knowledge:

**Try another university track**
- [Make DeepAgents reliable with Dapr Workflow](https://www.diagrid.io/university)
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Read more**
- Read [Announcing Durable Workflow for Agents](https://www.diagrid.io/blog/durable-workflows-ai-agents).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#ai* and language channels.
````

- [ ] **Step 4: Verify the `,run` commands and reset note**

Run: `grep -nE '```bash,run|flushall|audit-ledger' supply-chain-auditor/3-resume/assignment.md`
Expected: the re-run command, `cat audit-out/audit-ledger.log`, and the `flushall` + `rm` reset block are present, matching the demo README's reset instructions.

- [ ] **Step 5: Commit**

```bash
git add supply-chain-auditor/3-resume
git commit -m "Add supply-chain-auditor challenge 3 (resume and durability proof)"
```

---

## Task 5: Track-wide pre-flight verification

**Files:**
- Modify (only if issues found): any of the files created in Tasks 1–4.

**Interfaces:**
- Consumes: all files from Tasks 1–4.
- Produces: a verified, internally consistent track.

- [ ] **Step 1: Duration + challenge-count consistency**

Run: `grep -rn "challenges to complete\|takes about\|Time limit" supply-chain-auditor/README.md supply-chain-auditor/1-setup/notes.md supply-chain-auditor/*/assignment.md`
Expected: README says 3 challenges / 30-min limit; per-challenge intros say ~6, ~8, ~8 minutes (sum 22 < 30). Fix any mismatch.

- [ ] **Step 2: Every `tabs.md` uses the reused host and correct path**

Run: `grep -rn "host:\|path:" supply-chain-auditor/*/tabs.md`
Expected: every `host:` is `{{...}}` and every `path:` is `ai-agent-tracks-instruqt/langgraph/supply_chain_auditor`.

- [ ] **Step 3: Secret handling is correct**

Run: `grep -rn "ANTHROPIC_API_KEY\|your_key_here" supply-chain-auditor/1-setup`
Expected: `setup.sh` writes the placeholder; `assignment.md` tells the learner to replace it; `check.sh` rejects both empty and the placeholder; `solve.sh` overwrites it. No real key is ever committed anywhere in the track.

- [ ] **Step 4: No leftover placeholders or Catalyst instructions**

Run: `grep -rniE "TODO|TBD|diagrid dev run|DAPR_GRPC_ENDPOINT|catalyst" supply-chain-auditor/ || echo "clean"`
Expected: `clean` (the track uses only the local Dapr sidecar path).

- [ ] **Step 5: All shell scripts parse**

Run: `for f in $(find supply-chain-auditor -name '*.sh'); do bash -n "$f" && echo "OK $f"; done`
Expected: `OK` for all four scripts.

- [ ] **Step 6: Pre-flight items to check against the live environment (manual, before publishing)**

Confirm each, and note the result in the PR description:
- `dapr/dapr-agents#635` still parses as a single dependency bump **and** resolves to an upstream source repo, so the `analyze` (LLM) branch runs — not `finalize`. If it has drifted, pick another real single-bump Dependabot PR with a resolvable upstream and update `PR_REPO`/`PR_NUMBER`/`DEP_ECOSYSTEM` in `1-setup/scripts/setup.sh` (and the `dapr/dapr-agents#635` references in the assignments + the Redis `keys` glob in challenge 2).
- The exact Dapr **1.18** patch to pin in `sandbox-setup.sh` (`1.18.0` is a placeholder for the latest 1.18.x).
- `claude-sonnet-4-6` is reachable with a normal Anthropic key; otherwise document an `LLM_MODEL` override.
- A full two-run demo (`uv sync` → armed run → disarm → resume) completes within the sandbox time budget on the reused deepagents host.

- [ ] **Step 7: Final commit (if any fixes were made)**

```bash
git add supply-chain-auditor
git commit -m "Fix supply-chain-auditor track pre-flight issues"
```

---

## Self-Review notes (author)

- **Spec coverage:** scaffold/config (Task 1) ✔; ch1 setup + `.env` prefill + key validation (Task 2) ✔; ch2 run + armed crash + Redis inspection (Task 3) ✔; ch3 disarm + resume + ledger proof + reset + wrap-up (Task 4) ✔; reused host, Dapr 1.18, dry-run, no tests/CI in-repo, bare run command (Global Constraints + verified in Task 5) ✔. Security model appears as reading in ch1 (Task 2). No dedicated security challenge — matches the approved 3-challenge arc.
- **Out of scope confirmed absent:** no `tests/challenge.robot`, no CI workflow, no app-code changes, no new `_setup` image.
- **Type/name consistency:** app-id `supply-chain-auditor-langgraph`, instance-ID glob `audit-dapr-dapr-agents-635`, crash line `if ledger.count() >= 2: os._exit(1)`, ledger path `audit-out/audit-ledger.log`, env path `ai-agent-tracks-instruqt/langgraph/supply_chain_auditor/.env` — used identically across all tasks.
