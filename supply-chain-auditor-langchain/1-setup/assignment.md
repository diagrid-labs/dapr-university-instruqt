Welcome to **Make Langgraph durable with Dapr Workflow - Supply Chain Auditor**. In this track you'll run the _Supply Chain Auditor_, an AI agent that checks whether a Dependabot dependency bump's upstream release notes match its actual source code changes. The agent will intentionally crash, and by restarting it, you will see that none of the previously completed steps will be executed again. The agent is made durable with Dapr Workflow.

In this first challenge you'll set up the sandbox and add your Anthropic API key. This challenge takes about 5 minutes to complete.

## The attack

A dependency update's changelog is written by whoever published the release — including an attacker. The classic supply-chain attack ships malicious code (an install hook, a credential grab, an obfuscated payload) inside an update whose notes say something innocent like "documentation only". If you trust the changelog, you merge the attack.

## The auditor

The _Supply Chain Auditor_ is a staged [LangGraph](https://www.langchain.com/langgraph) pipeline:

```text,nocopy
START → gather_evidence → ┬─ analyze  ─┐→ render_report → END
                          └─ finalize ─┘
        (resolve repo,      (Claude judges    (Markdown report)
         fetch notes+diff,    notes vs diff,
         run heuristics)      reconciled)
```

- **`gather_evidence`** (graph.py, line 64) resolves the bumped package to its upstream GitHub repo, fetches the release notes and the real source diff, and runs deterministic red-flag heuristics — no LLM.
- **`analyze`** (graph.py, line 90) is the only node that calls **Claude**. It grounds its judgement in the untrusted, nonce-tagged evidence and produces a structured verdict.
- **`render_report`** (graph.py, line 122) renders the verdict to a Markdown comment.

Every node runs as a durable **Dapr Workflow activity** — which is what makes the crash-and-resume in the next challenges possible.

> [!NOTE]
> You can use the **Editor** window on the left to inspect the code.

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
> You should see both a **CLI version** and a **Runtime version**. If the Runtime version is blank, run `dapr init`. If you hit any other blocking issue during this track, send me [an email](mailto:marc@diagrid.io) and we'll figure it out together.

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

You've got a working sandbox, the _Supply Chain Auditor_ cloned, and your key in place. Next you'll run the audit as a durable Dapr Workflow — and crash it on purpose.
