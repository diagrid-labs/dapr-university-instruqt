# New University Track Ideas — Reliable GitHub-Analysis Agents

Five new Dapr University tracks that each build a **practical AI agent for developers** on top of a
different agent framework. Every track tackles the same real-world theme — **making sense of the flood
of issues and pull requests in a large, high-volume open-source repository** — but each one uses a
distinct framework and showcases a distinct Dapr/Catalyst reliability feature.

The single message that runs through all five tracks:

> **The agent framework does the reasoning. Dapr (and Diagrid Catalyst) makes it reliable** —
> durable execution that survives crashes, automatic retries/timeouts/circuit breakers on flaky LLM and
> network calls, durable state, and built-in observability.

---

## Shared design constraints

These apply to every track and are the guardrails that keep the tracks self-contained and finishable in
the time budget.

| Constraint | Decision |
| --- | --- |
| **LLM provider** | Default to a **small local model via Ollama** (e.g. `llama3.2:3b` or `qwen2.5:3b`), pre-pulled in the sandbox image so there's no download wait. A **hosted-provider fallback** (OpenAI/Anthropic via the Dapr Conversation API) is documented for learners who want faster inference. No other LLM keys required. |
| **No 3rd-party SaaS** | Nothing that needs a signup or API key beyond the LLM provider and GitHub. No Tavily, no vector-DB SaaS, no observability SaaS. Any vector/embedding step uses a local model or in-process store. |
| **GitHub access** | Learner runs **`BROWSER=true gh auth login --hostname github.com --git-protocol https --web`** once, then opens **https://github.com/login/device** in their own browser and enters the one-time code printed in the terminal (no PAT to paste; `BROWSER=true` suppresses the headless-VM "can't open a browser" error). The app then reads the token via **`gh auth token`** at startup and uses a **native GitHub SDK** (Octokit.NET in .NET, PyGithub in Python). This gives read-only access with generous authenticated rate limits and works against any public repo. |
| **No write access** | Every track is **read-only** against the target repo. The deliverable is always a **report, digest, or recommendation** (printed, written to a local file, or surfaced in a small UI) — never a label, comment, or status change pushed back to GitHub. |
| **Target repo** | Use a genuinely high-volume public repo so the "large number of issues/PRs" premise is real — e.g. `kubernetes/kubernetes`, `microsoft/vscode`, `golang/go`, or `dapr/dapr`. Learners can point the agent at any repo they like. |
| **Time budget** | 30–40 minutes, 3–4 challenges each. |
| **Reliability proof** | Each track includes a "**kill it and watch it recover**" moment — the learner interrupts the process (Ctrl-C / kill the app) mid-run and restarts to see Dapr resume durable work instead of starting over. This is the concrete payoff, not just a slide. |

### Why Dapr/Catalyst, concretely

The reliability features each track can draw on, so the "Dapr makes it reliable" claim is shown, not asserted:

- **Durable execution (Dapr Workflow / Dapr Agents):** workflow and agent state is checkpointed; a crash
  resumes from the last completed step instead of replaying the whole run or losing partial work.
- **Resiliency policies (Dapr Conversation API + resiliency spec):** retries, timeouts, and circuit
  breakers on LLM calls and tool/HTTP calls — declared in config, not hand-coded into the agent loop.
- **Durable state (Dapr state store):** the agent's scratchpad, intermediate findings, and dedup index
  survive restarts.
- **Observability:** built-in tracing (Zipkin in the sandbox) so learners can see every LLM and tool hop.
- **Diagrid Catalyst:** the managed-Dapr option — the same Conversation API and Workflow APIs without
  running the control plane yourself. Featured as the "take this to production" path, especially in
  Tracks 1 and 3.

---

## Technical implementation notes

How the `gh` CLI is actually used from the application code, what ships pre-coded vs. what the learner
writes, and the risks/alternatives that shaped those decisions. This applies across all five tracks.

### The core mechanism

`BROWSER=true gh auth login --hostname github.com --git-protocol https --web` writes a token to
`~/.config/gh/hosts.yml` (or the OS keyring) — the learner authorizes by opening
**https://github.com/login/device** and entering the one-time code shown in the terminal (`BROWSER=true`
avoids the failed-browser exec error on the headless VM). The app reads that token
**once at startup** via `gh auth token` and hands it to a **native GitHub SDK client** — **Octokit.NET** in
.NET, **PyGithub** in Python. From there every GitHub call goes through the SDK: connection reuse (no per-call
process spawn), typed responses, real pagination, and built-in retry. The learner never pastes a PAT and the
application code never hard-codes a credential.

The constraint this creates: the app process must run in the **same user/home context** where
`gh auth login` ran, so `gh auth token` can read the stored credential. With Dapr Workflow activities
(Tracks 1, 3, 4, 5) this holds — activities run *in-process* in the same app the learner launches via
`dapr run`. It only breaks if the token read is attempted from a separate container or user.

### .NET (Track 1 — MAF)

A `GitHubClient` helper reads the token via `gh auth token` once, builds an **Octokit.NET** client, and is
registered as an MAF tool (an `AIFunction` with a `[Description]`) so the agent can call e.g.
`GetPullRequestFiles(number)`:

```csharp
// pre-coded helper — token read once at startup, client reused for every call
var token = (await ShellAsync("gh", "auth", "token")).Trim();
var github = new GitHubClient(new ProductHeaderValue("dapr-university"))
{
    Credentials = new Credentials(token),
};

// typed call — no subprocess, no JSON plumbing
IReadOnlyList<PullRequestFile> files =
    await github.PullRequest.Files(owner, repo, number);
```

The Dapr Workflow activity calls the MAF agent → the agent calls the tool → the tool uses the Octokit client.

### Python (Tracks 2–5)

Same shape with **PyGithub**: read the token once, build a `Github` client, then wrap the typed calls as a
framework-native tool (the decorator differs per framework — Dapr Agents `@tool`, LangGraph `@tool`/`ToolNode`,
Strands `@tool`, DeepAgents tool — but the body is the same):

```python
# pre-coded helper — token read once at startup, client reused for every call
import subprocess
from github import Github

token = subprocess.run(
    ["gh", "auth", "token"], capture_output=True, text=True, check=True,
).stdout.strip()
gh = Github(token)

# typed, paginated — no subprocess per call
def get_pr_files(owner: str, repo: str, number: int):
    return list(gh.get_repo(f"{owner}/{repo}").get_pull(number).get_files())
```

### Pre-coded vs. learner-written

The learner should never write subprocess/JSON plumbing — that's noise. They write the agent and workflow
code, which is the point of each track.

| Pre-coded (cloned repo / setup) | Learner writes |
| --- | --- |
| The token bootstrap (`gh auth token`) + Octokit.NET / PyGithub client and DTOs | The **tool registration** — exposing the client wrapper as a framework tool |
| Project scaffold, `pyproject.toml` / `.csproj`, dependencies | The **agent definition + prompt** (triage / risk / dedup logic) |
| Dapr component YAML (Conversation, state store) + resiliency spec | The **workflow orchestrator** (fan-out/fan-in, activity calls) |
| `setup.sh` that prompts the `gh auth login` web device flow (`BROWSER=true … --web`) and pre-pulls the Ollama model | The line that **wires the tool into the agent** and the run command |
| Markdown report writer | Sometimes the report-assembly step |

### Risks

1. **Auth context lost at runtime.** If the app runs where `~/.config/gh` isn't reachable (different user,
   container, or a sidecar-spawned process), every `gh` call fails. *Highest-likelihood track-breaker.*
2. **`gh auth login` device flow inside Instruqt.** Interactive — the learner opens
   https://github.com/login/device and pastes the one-time code. `BROWSER=true … --web` keeps it clean on the
   headless VM (no failed-browser error), but it's still a manual two-step the challenge text must spell out.
3. **Network latency at fan-out.** The SDK reuses one connection (the per-call process-spawn cost is gone),
   but a fan-out over 50 PRs × several calls each is still many network round-trips — budget for it and cap
   batch size.
4. **Secondary rate limits / abuse detection.** Authenticated is 5,000 req/hr, but bursts can trip GitHub's
   secondary limits and return 403s mid-run — ironically failing *during* the "watch it recover" demo.
5. **Payload size vs. context window.** A real PR diff or long issue thread easily exceeds a 3B model's
   context; tool output must be truncated/summarized before reaching the LLM.
6. **Non-determinism.** A live high-volume repo changes between runs, so expected output / screenshots drift.
7. **Arg injection.** Essentially moot — the only subprocess call is `gh auth token` (no user input); all
   GitHub access goes through the typed SDK.
8. **`gh` version / PATH drift** across the sandbox image (still relevant for the one-time `gh auth token` read).

### Alternatives (ranked)

1. **Pre-fetch a snapshot in `setup.sh`.** The setup script runs the GitHub calls once and writes fixed JSON
   files (or pins specific issue/PR numbers); the app reads local files as its GitHub source. Eliminates
   risks #1, #3, #4, and #6 and makes the track deterministic, at the cost of being no longer "live."
   Strong option for demo stability — can be combined with the default SDK approach (live for the lesson,
   snapshot as fallback).
2. **Raw `gh api` subprocessing.** Shell out to `gh api` per call instead of the SDK. Simpler to read but
   reintroduces per-call process-spawn latency and manual JSON/pagination — keep it only where a track's goal
   is explicitly to *teach* "the agent shells out to a CLI tool."

**Recommendation:** default to **`gh auth token` + native SDK** (Octokit.NET / PyGithub) for runtime calls —
it gives clean no-PAT auth plus connection reuse, typed responses, pagination, and retry — and **pre-fetch a
pinned snapshot in `setup.sh`** as the determinism safety net.

---

## Track 1 — Microsoft Agent Framework + Dapr Workflow *(required pairing)*

**Working title:** *Reliable PR Digests with Microsoft Agent Framework and Dapr Workflow*
**Framework:** Microsoft Agent Framework (the unified successor to Semantic Kernel + AutoGen)
**Language:** **.NET / C#** (plays to MAF's strongest SDK and your existing .NET workflow tracks)
**Estimated time:** ~40 minutes, 4 challenges

### Use case
A maintainer drowning in open PRs wants a **daily digest**. The app fans out over a batch of open PRs and,
for each one, runs an MAF agent that **summarizes the change, checks whether it references an issue, and
flags risk signals** (touches many files, no tests, large diff). Results fan in to a single ranked
markdown digest the maintainer can skim in two minutes.

### The reliability angle
A batch of 20–50 PRs, each needing a slow local LLM call, is exactly where naive scripts fall over — one
crash and you re-run everything. **Dapr Workflow** drives the fan-out/fan-in as a **durable orchestration**:
each PR's analysis is a workflow activity, checkpointed on completion. Kill the app halfway through and
restart — the workflow resumes from the next unprocessed PR. **Resiliency policies** wrap the LLM activity
so a flaky model call is retried with backoff instead of aborting the digest. MAF owns the per-PR agent
reasoning; Dapr Workflow owns the durable, parallel, retryable orchestration around it.

### Challenge outline
1. **What we're building & setup** — concepts: MAF agents vs. Dapr Workflow orchestration; GitHub auth via the
   `gh auth login` web device flow (open https://github.com/login/device, enter the terminal code); confirm
   Ollama model. Pull a list of open PRs with `gh pr list --json`.
2. **A single PR-analysis agent (MAF)** — build one MAF agent with a tool that fetches a PR's files/diff via
   `gh api`; prompt it to emit a structured summary + risk score. Run it on one PR.
3. **Durable fan-out/fan-in (Dapr Workflow)** — wrap the agent call as a workflow activity; orchestrator
   fans out across all PRs, fans in to a digest. Add a resiliency policy (retries/timeout) on the LLM call.
4. **Crash & resume** — start the digest over a large batch, kill the app mid-run, restart, and watch the
   workflow continue from where it stopped. Inspect the trace in Zipkin. Mention Diagrid Catalyst as the
   managed path to run the same workflow in production.

### Output artifact
`pr-digest.md` — ranked list of open PRs with one-line summaries, linked-issue status, and risk flags.

### Dependencies
.NET SDK, Dapr CLI + workflow, Microsoft Agent Framework NuGet, `gh` CLI, Ollama (local model).

---

## Track 2 — Dapr Agents

**Working title:** *An Issue-Triage Agent that Never Loses Its Place*
**Framework:** Dapr Agents (`DurableAgent`)
**Language:** Python
**Estimated time:** ~35 minutes, 3–4 challenges

### Use case
New issues arrive faster than maintainers can sort them. A **triage agent** reads a batch of recently
opened issues and, for each, produces a **triage recommendation**: category (bug / feature / question /
docs), suggested labels, a likely-duplicate flag, and a priority guess — all collated into a triage report
the maintainer reviews before touching the repo.

### The reliability angle
This is the **native** Dapr story: a `DurableAgent` already runs on Dapr Workflow under the hood, so its
state, tool-call history, and progress are **durable by default**. The track makes that visible — the agent
processes issues one by one, and if interrupted it resumes mid-batch with its conversation/state intact,
no re-work. The Conversation API gives provider-agnostic LLM access (swap Ollama ↔ OpenAI by editing a
component file, not code) plus retries on transient failures.

### Challenge outline
1. **What is a triage agent & setup** — Dapr Agents recap, GitHub auth via the `gh auth login` web device flow
   (open https://github.com/login/device, enter the terminal code), Conversation component pointed
   at Ollama (with the swap-to-hosted note). Fetch recent issues via `gh issue list --json`.
2. **Build the DurableAgent** — define triage tools (fetch issue body/comments, list recent issues for the
   dedup check) and the triage prompt; run it over a few issues.
3. **Durability in action** — run over a larger batch, kill the agent mid-batch, restart, and confirm it
   resumes without redoing completed issues. Show the durable state in the state store.
4. *(optional)* **Swap the model & add resiliency** — flip the Conversation component to a hosted provider;
   add a resiliency policy; re-run.

### Output artifact
`triage-report.md` — per-issue category, suggested labels, duplicate-of hint, and priority.

### Dependencies
Python + uv, Dapr CLI + Dapr Agents, `gh` CLI, Ollama.

---

## Track 3 — LangGraph

**Working title:** *Durable Duplicate Detection with LangGraph and Dapr Workflow*
**Framework:** LangGraph (stateful graph orchestration)
**Language:** Python
**Estimated time:** ~40 minutes, 4 challenges

### Use case
Duplicate issues are the single biggest time sink for maintainers of popular repos. The learner builds a
**duplicate-detection graph**: given a target issue, the graph gathers candidate recent issues, compares
them (local embeddings + an LLM adjudication node), and outputs a ranked **"likely duplicates"** list with
reasoning.

### The reliability angle
LangGraph models the reasoning beautifully as a graph, but its built-in checkpointers are **local and
ephemeral** (in-memory / SQLite) — fine for a laptop, not for a service that must survive restarts or scale
out. This track shows two complementary fixes: (1) wrap the LangGraph run inside a **Dapr Workflow** so the
overall job is durably orchestrated and restartable, and (2) route the graph's LLM calls through the **Dapr
Conversation API** so retries/timeouts/circuit breakers are declarative. The teaching beat: *you keep
LangGraph's ergonomics and gain distributed durability + resiliency you'd otherwise hand-roll.* This is the
best track to feature **Diagrid Catalyst** as the managed Conversation + Workflow backend.

### Challenge outline
1. **The duplicate problem & setup** — LangGraph basics, GitHub auth via the `gh auth login` web device flow
   (open https://github.com/login/device, enter the terminal code), Ollama. Fetch a target issue +
   recent issues via `gh`.
2. **Build the LangGraph graph** — nodes: gather candidates → embed/compare (local) → LLM adjudicate →
   rank. Run it once and note the ephemeral checkpointer limitation.
3. **Make it durable with Dapr** — wrap the graph invocation in a Dapr Workflow; move LLM calls to the
   Conversation API with a resiliency policy.
4. **Crash, resume & go managed** — interrupt mid-run and resume; then point the Conversation/Workflow
   components at Diagrid Catalyst to show the same code running on managed Dapr.

### Output artifact
`duplicates-<issue#>.md` — ranked candidate duplicates with similarity scores and LLM rationale.

### Dependencies
Python + uv, Dapr CLI + workflow, LangGraph, a local embeddings model (via Ollama), `gh` CLI.

---

## Track 4 — Strands

**Working title:** *A Resilient "Good First Issue" Finder with Strands*
**Framework:** Strands Agents SDK (model-driven agent loop)
**Language:** Python
**Estimated time:** ~35 minutes, 3 challenges

### Use case
Growing a contributor base means surfacing approachable work. The learner builds a **good-first-issue
finder**: a Strands agent scans open issues, judges which are genuinely newcomer-friendly (clear scope,
low blast radius, no deep context required), and drafts a short **onboarding note** for each — a ready-made
"here's how to get started" the maintainer can later post.

### The reliability angle
Strands' model-driven agent loop is concise and elegant, but the loop's many LLM/tool iterations are a
**resiliency liability** on a small local model that occasionally times out or returns garbage. This track
wraps the Strands run in a **Dapr Workflow** so the overall scan is durable and restartable, and sends the
agent's model calls through the **Dapr Conversation API** for declarative retries/timeouts. The learner sees
a deliberately induced model timeout get retried transparently instead of crashing the run.

### Challenge outline
1. **Strands + the GFI use case & setup** — Strands agent-loop basics, GitHub auth via the `gh auth login` web
   device flow (open https://github.com/login/device, enter the terminal code), Ollama; configure
   Strands to use the local model. Fetch open issues via `gh`.
2. **Build the finder agent** — tools to read issue details and labels; prompt the agent to score
   newcomer-friendliness and draft an onboarding note. Run over a sample.
3. **Add Dapr resiliency** — wrap in a Dapr Workflow + Conversation API resiliency policy; trigger a
   timeout/retry and an interrupt-and-resume to prove durability.

### Output artifact
`good-first-issues.md` — shortlisted issues, friendliness scores, and draft onboarding notes.

### Dependencies
Python + uv, Dapr CLI + workflow, Strands Agents SDK, `gh` CLI, Ollama.

---

## Track 5 — DeepAgents

**Working title:** *Deep Issue Investigation that Survives the Long Haul*
**Framework:** DeepAgents (LangChain's planning + sub-agents + virtual filesystem, built on LangGraph)
**Language:** Python
**Estimated time:** ~40 minutes, 3–4 challenges

### Use case
Some issues are a rabbit hole — they reference other issues, span multiple PRs, and bury the real cause in
a long comment thread. The learner builds a **deep investigation agent** that takes **one gnarly issue** and
runs a **long-horizon investigation**: plan the steps, pull related issues and linked PRs, read the comment
history, and write up an **in-depth analysis report** (probable cause, related work, suggested next steps).

### The reliability angle
DeepAgents is purpose-built for long, multi-step work with sub-agents and a scratchpad filesystem — which is
precisely the workload most likely to be interrupted partway through and most expensive to restart from
scratch. This track backs DeepAgents with **Dapr durable state** for its scratchpad/working files and a
**Dapr Workflow** as the durable outer driver, so a long investigation **resumes mid-plan** after a crash
rather than re-running every expensive step. Conversation API resiliency covers the individual model calls.

### Challenge outline
1. **DeepAgents & the deep-investigation use case & setup** — planning/sub-agent/filesystem concepts,
   GitHub auth via the `gh auth login` web device flow (open https://github.com/login/device, enter the
   terminal code), Ollama. Pick a target issue.
2. **Build the deep agent** — equip it with `gh`-backed tools (read issue, list linked PRs, fetch comments,
   search related issues) and a planning prompt; run a single investigation and watch it plan + delegate.
3. **Durable scratchpad with Dapr** — back the agent's working files with a Dapr state store; wrap the run
   in a Dapr Workflow.
4. **Interrupt a long run & resume** — kill the agent mid-investigation and restart; confirm the plan and
   partial findings are intact and it continues instead of restarting. Inspect the trace.

### Output artifact
`investigation-<issue#>.md` — structured deep-dive: timeline, related issues/PRs, probable cause, next steps.

### Dependencies
Python + uv, Dapr CLI + workflow, DeepAgents (LangChain), `gh` CLI, Ollama.

---

## Cross-track summary

| # | Framework | Lang | Use case | Headline Dapr feature | Output |
| --- | --- | --- | --- | --- | --- |
| 1 | Microsoft Agent Framework + Dapr Workflow | .NET | PR digest (fan-out/fan-in) | Durable orchestration + retries | `pr-digest.md` |
| 2 | Dapr Agents | Python | Issue triage | `DurableAgent` durable-by-default | `triage-report.md` |
| 3 | LangGraph | Python | Duplicate detection | Durable wrap + Conversation API resiliency (+ Catalyst) | `duplicates-<#>.md` |
| 4 | Strands | Python | Good-first-issue finder | Resiliency policies on a flaky agent loop | `good-first-issues.md` |
| 5 | DeepAgents | Python | Deep issue investigation | Durable state + workflow for long-horizon work | `investigation-<#>.md` |

### Suggested build order
1. **Track 2 (Dapr Agents)** — most native, lowest risk, validates the shared `gh` + Ollama setup harness.
2. **Track 1 (MAF + Dapr Workflow)** — the required pairing; reuses the workflow pattern other tracks lean on.
3. **Tracks 3 → 4 → 5** — each adds one external framework on top of the now-proven Dapr scaffolding.

### Open questions to resolve during track build
- Confirm the default Ollama model and verify acceptable inference latency for a 20–50 item batch on the
  sandbox VM (CPU-only). If too slow, reduce batch size or lean harder on the hosted fallback.
- The chosen auth path is the `gh auth login` web device flow (`BROWSER=true … --web`) with the learner
  opening https://github.com/login/device manually. Confirm this two-step reads cleanly inside an Instruqt
  challenge step, or whether a short-lived token passed via sandbox env is smoother for learners.
- Pick one canonical demo repo per track (or a shared one) so screenshots/expected output stay stable.
- For Track 3, choose the local embeddings approach (Ollama embeddings model vs. a small in-process library).
