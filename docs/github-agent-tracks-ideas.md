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
| **GitHub access** | **No runtime GitHub access or authentication.** Issue and PR data is fetched **once when the sandbox VM image is created** by a data-collection helper script and persisted to local JSON files baked into the image. At runtime the app reads only these local files through a read helper — no `gh` CLI, no token, no network calls to GitHub. This makes every track deterministic and offline. |
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

How GitHub data is collected once at VM creation, how the application reads it locally at runtime, and
what ships pre-coded vs. what the learner writes. This applies across all five tracks.

### The core mechanism

GitHub issue and PR data is collected **once, when the sandbox VM image is created** — never at sandbox
startup and never at runtime. A data-collection helper script runs during image build, fetches the
relevant issues/PRs for the target repo, and writes them to local JSON files under a per-repo data directory
(`data/<owner>/<repo>/`, so multiple repos stay isolated). A build-time GitHub token is supplied to that
script as an environment variable **during
the build only**; it is never present in the running sandbox, so the learner never authenticates and never
sees a token.

At runtime the application reads exclusively from those local JSON files through a small read helper. There
are **no GitHub network calls, no `gh` CLI invocations, and no credentials** in the running app. Every
track is therefore deterministic, offline, and free of rate-limit and auth failures.

The helper has two halves:

1. **Collector (build time):** persists issues/PRs to local JSON. Run once per image build.
2. **Reader (runtime):** deserializes the local JSON into typed objects and exposes them to the
   agent/workflow as a framework tool.

### Collector — build time

A script run during VM image creation fetches the data once and writes JSON files. It can use the GitHub
REST API directly or a native SDK with a build-time token; only the output matters — fixed JSON files baked
into the image:

```python
# collect_github_data.py — runs ONCE at VM image creation, never at runtime.
# GITHUB_TOKEN is a build-time env var only; it is absent in the running sandbox.
import json, os
from pathlib import Path
from github import Github

OWNER, REPO = "dapr", "dapr"
DATA = Path("data") / OWNER / REPO   # one subtree per repo, so multiple repos stay isolated

gh = Github(os.environ["GITHUB_TOKEN"])
repo = gh.get_repo(f"{OWNER}/{REPO}")

(DATA / "prs").mkdir(parents=True, exist_ok=True)
for pr in repo.get_pulls(state="open")[:50]:
    files = [{"filename": f.filename, "additions": f.additions,
              "deletions": f.deletions, "patch": f.patch} for f in pr.get_files()]
    (DATA / "prs" / f"{pr.number}.json").write_text(json.dumps(
        {"number": pr.number, "title": pr.title, "body": pr.body, "files": files}, indent=2))

(DATA / "issues").mkdir(parents=True, exist_ok=True)
for issue in repo.get_issues(state="open")[:100]:
    if issue.pull_request:        # GitHub surfaces PRs as issues too — skip them
        continue
    comments = [c.body for c in issue.get_comments()]
    (DATA / "issues" / f"{issue.number}.json").write_text(json.dumps(
        {"number": issue.number, "title": issue.title, "body": issue.body,
         "labels": [l.name for l in issue.labels], "comments": comments}, indent=2))
```

### Reader — runtime (.NET, Track 1 — MAF)

A `GitHubDataReader` helper deserializes the local JSON into typed DTOs and is registered as an MAF tool (an
`AIFunction` with a `[Description]`) so the agent can call e.g. `GetPullRequestFiles(number)`:

```csharp
// pre-coded read helper — reads local JSON, no network, no token.
// repoDir points at one repo's snapshot, e.g. "data/dapr/dapr".
public sealed class GitHubDataReader(string repoDir = "data/dapr/dapr")
{
    public async Task<IReadOnlyList<PullRequestFile>> GetPullRequestFiles(int number)
    {
        var path = Path.Combine(repoDir, "prs", $"{number}.json");
        var json = await File.ReadAllTextAsync(path);
        return JsonSerializer.Deserialize<PullRequest>(json)!.Files;
    }
}
```

The Dapr Workflow activity calls the MAF agent → the agent calls the tool → the tool reads the local data.

### Reader — runtime (Python, Tracks 2–5)

Same shape: a pre-coded module reads the local JSON, then the typed calls are wrapped as a framework-native
tool (the decorator differs per framework — Dapr Agents `@tool`, LangGraph `@tool`/`ToolNode`, Strands
`@tool`, DeepAgents tool — but the body is the same):

```python
# github_data.py — pre-coded read helper used at runtime. No network, no token.
import json
from pathlib import Path

DATA = Path("data") / "dapr" / "dapr"   # one repo's snapshot: data/<owner>/<repo>/

def list_issues() -> list[dict]:
    return [json.loads(p.read_text()) for p in sorted((DATA / "issues").glob("*.json"))]

def get_issue(number: int) -> dict:
    return json.loads((DATA / "issues" / f"{number}.json").read_text())

def get_pr_files(number: int) -> list[dict]:
    return json.loads((DATA / "prs" / f"{number}.json").read_text())["files"]
```

### Pre-coded vs. learner-written

The learner should never write subprocess/JSON plumbing — that's noise. They write the agent and workflow
code, which is the point of each track.

| Pre-coded (image build / cloned repo) | Learner writes |
| --- | --- |
| The **collector script** (run at VM creation) + the local JSON data + the **reader helper** and DTOs | The **tool registration** — exposing the reader wrapper as a framework tool |
| Project scaffold, `pyproject.toml` / `.csproj`, dependencies | The **agent definition + prompt** (triage / risk / dedup logic) |
| Dapr component YAML (Conversation, state store) + resiliency spec | The **workflow orchestrator** (fan-out/fan-in, activity calls) |
| `setup.sh` that pre-pulls the Ollama model | The line that **wires the tool into the agent** and the run command |
| Markdown report writer | Sometimes the report-assembly step |

### Risks

1. **Payload size vs. context window.** A real PR diff or long issue thread easily exceeds a 3B model's
   context; the reader/tool output must be truncated or summarized before reaching the LLM.
2. **Data staleness.** The local snapshot reflects the target repo at image-build time and refreshes only on
   rebuild. This is the accepted price of determinism — call it out in the track text so the data doesn't
   look "live."
3. **Snapshot scope must match access patterns.** The collector must fetch everything the agent might read.
   Bounded tracks (1–4: a fixed batch of PRs or a recent-issues set) are easy. Track 5's deep investigation
   navigates dynamically (linked PRs, related-issue search), so its collector must pre-fetch a *neighborhood*
   around the pinned issue, and any "search" tool must query the local set rather than GitHub.
4. **Build-time collection failures.** Rate limits or network errors during the fetch fail the image build
   rather than the learner's run — contained, but the collector should paginate politely and be re-runnable.

### Alternatives (ranked)

1. **Live GitHub access at runtime (not used).** Querying the GitHub API while the app runs keeps the data
   current and lets learners point at any repo on the fly, but it reintroduces runtime authentication, rate
   limits, network latency, and non-determinism — the exact failure modes the build-time snapshot removes.
   Not worth it for a time-boxed, reproducible track.
2. **Refresh cadence.** If currency matters, rebuild the VM image (and re-run the collector) on a schedule so
   the snapshot stays reasonably fresh without sacrificing per-run determinism.

**Recommendation:** collect once at VM creation into local JSON, read locally at runtime. Deterministic,
offline, no auth, no rate limits — and the reliability story (durable workflow/agent state surviving a crash)
is unaffected because it never depended on the data source.

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
1. **What we're building & setup** — concepts: MAF agents vs. Dapr Workflow orchestration; confirm the local
   GitHub data was collected into JSON at VM creation; confirm Ollama model. Load the list of open PRs from
   the local data via the reader helper.
2. **A single PR-analysis agent (MAF)** — build one MAF agent with a tool that fetches a PR's files/diff from
   the local data via the reader helper; prompt it to emit a structured summary + risk score. Run it on one PR.
3. **Durable fan-out/fan-in (Dapr Workflow)** — wrap the agent call as a workflow activity; orchestrator
   fans out across all PRs, fans in to a digest. Add a resiliency policy (retries/timeout) on the LLM call.
4. **Crash & resume** — start the digest over a large batch, kill the app mid-run, restart, and watch the
   workflow continue from where it stopped. Inspect the trace in Zipkin. Mention Diagrid Catalyst as the
   managed path to run the same workflow in production.

### Output artifact
`pr-digest.md` — ranked list of open PRs with one-line summaries, linked-issue status, and risk flags.

### Dependencies
.NET SDK, Dapr CLI + workflow, Microsoft Agent Framework NuGet, Ollama (local model). (GitHub data is pre-collected into local JSON at VM creation.)

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
1. **What is a triage agent & setup** — Dapr Agents recap, confirm the local GitHub data collected into JSON
   at VM creation, Conversation component pointed at Ollama (with the swap-to-hosted note). Load recent issues
   from the local data via the reader helper.
2. **Build the DurableAgent** — define triage tools (fetch issue body/comments, list recent issues for the
   dedup check) and the triage prompt; run it over a few issues.
3. **Durability in action** — run over a larger batch, kill the agent mid-batch, restart, and confirm it
   resumes without redoing completed issues. Show the durable state in the state store.
4. *(optional)* **Swap the model & add resiliency** — flip the Conversation component to a hosted provider;
   add a resiliency policy; re-run.

### Output artifact
`triage-report.md` — per-issue category, suggested labels, duplicate-of hint, and priority.

### Dependencies
Python + uv, Dapr CLI + Dapr Agents, Ollama. (GitHub data is pre-collected into local JSON at VM creation.)

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
1. **The duplicate problem & setup** — LangGraph basics, confirm the local GitHub data collected into JSON at
   VM creation, Ollama. Load a target issue + recent issues from the local data via the reader helper.
2. **Build the LangGraph graph** — nodes: gather candidates → embed/compare (local) → LLM adjudicate →
   rank. Run it once and note the ephemeral checkpointer limitation.
3. **Make it durable with Dapr** — wrap the graph invocation in a Dapr Workflow; move LLM calls to the
   Conversation API with a resiliency policy.
4. **Crash, resume & go managed** — interrupt mid-run and resume; then point the Conversation/Workflow
   components at Diagrid Catalyst to show the same code running on managed Dapr.

### Output artifact
`duplicates-<issue#>.md` — ranked candidate duplicates with similarity scores and LLM rationale.

### Dependencies
Python + uv, Dapr CLI + workflow, LangGraph, a local embeddings model (via Ollama). (GitHub data is pre-collected into local JSON at VM creation.)

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
1. **Strands + the GFI use case & setup** — Strands agent-loop basics, confirm the local GitHub data collected
   into JSON at VM creation, Ollama; configure Strands to use the local model. Load open issues from the local
   data via the reader helper.
2. **Build the finder agent** — tools to read issue details and labels; prompt the agent to score
   newcomer-friendliness and draft an onboarding note. Run over a sample.
3. **Add Dapr resiliency** — wrap in a Dapr Workflow + Conversation API resiliency policy; trigger a
   timeout/retry and an interrupt-and-resume to prove durability.

### Output artifact
`good-first-issues.md` — shortlisted issues, friendliness scores, and draft onboarding notes.

### Dependencies
Python + uv, Dapr CLI + workflow, Strands Agents SDK, Ollama. (GitHub data is pre-collected into local JSON at VM creation.)

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
1. **DeepAgents & the deep-investigation use case & setup** — planning/sub-agent/filesystem concepts, confirm
   the local GitHub data collected into JSON at VM creation (a pre-fetched neighborhood around the target
   issue), Ollama. Pick a target issue.
2. **Build the deep agent** — equip it with tools backed by the local data (read issue, list linked PRs, fetch
   comments, search related issues over the local set) and a planning prompt; run a single investigation and
   watch it plan + delegate.
3. **Durable scratchpad with Dapr** — back the agent's working files with a Dapr state store; wrap the run
   in a Dapr Workflow.
4. **Interrupt a long run & resume** — kill the agent mid-investigation and restart; confirm the plan and
   partial findings are intact and it continues instead of restarting. Inspect the trace.

### Output artifact
`investigation-<issue#>.md` — structured deep-dive: timeline, related issues/PRs, probable cause, next steps.

### Dependencies
Python + uv, Dapr CLI + workflow, DeepAgents (LangChain), Ollama. (GitHub data is pre-collected into local JSON at VM creation.)

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
1. **Track 2 (Dapr Agents)** — most native, lowest risk, validates the shared local-data + Ollama setup harness.
2. **Track 1 (MAF + Dapr Workflow)** — the required pairing; reuses the workflow pattern other tracks lean on.
3. **Tracks 3 → 4 → 5** — each adds one external framework on top of the now-proven Dapr scaffolding.

### Open questions to resolve during track build
- Confirm the default Ollama model and verify acceptable inference latency for a 20–50 item batch on the
  sandbox VM (CPU-only). If too slow, reduce batch size or lean harder on the hosted fallback.
- Confirm the data-collection step runs cleanly during VM image creation for the chosen repo(s), and decide
  the snapshot size/limits per track (number of PRs/issues, whether to store full diffs) to balance realism
  against image size and the model's context window.
- For Track 5, define how large a "neighborhood" the collector pre-fetches around the target issue (linked
  PRs, referenced issues, search results) so the deep investigation has enough to traverse without ballooning.
- Pick one canonical demo repo per track (or a shared one) so screenshots/expected output stay stable.
- For Track 3, choose the local embeddings approach (Ollama embeddings model vs. a small in-process library).
