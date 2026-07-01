This is the durability demo. You'll interrupt the workflow with a **real process crash**, restart it, and prove that the `PrAnalyzer` agent calls that already completed are **not** run again on resume. It will take about 5 minutes.

## 1. How it's made provable

Two mechanisms make durability something you can see rather than take on faith:

- **A deterministic crash gate.** Set `CRASH_AFTER_AGENT_CALLS=<N>` before launching and the API hard-crashes (via `Environment.FailFast`) exactly once, right after the Nth agent call. A marker file ensures the restarted process never crashes at the same point again.
- **An agent-call ledger.** Every executed agent call appends one line to `agent-calls.log` — `<timestamp>  PR #<number>  <title>`. Recording happens inside a *checkpointed workflow activity*, so on resume a completed record is replayed from durable history and is **not** appended again. The finished ledger therefore holds each PR exactly once, with a visible time gap at the moment of restart.

## 2. Arm the crash gate and launch

First stop the running app: click the *Aspire Terminal* and press `Ctrl+C`.

Then arm the gate to crash after 3 agent calls (7 PRs total, so 4 remain for the resumed run) and start Aspire again. Run in the *Aspire Terminal*:

```shell,run,copy
export DIGEST_OUTPUT_DIR=/root/digest-out
export CRASH_AFTER_AGENT_CALLS=3
aspire run
```

Wait until the resources show **Running** in the *Aspire* tab.

## 3. Start a run and watch it crash

In the *Curl Terminal*, start a new workflow:

```curl,run
curl -X POST "http://localhost:5090/start" -H "Content-Type: application/json" -d '{
  "id": "run-crash",
  "repo": "dapr/dapr",
  "maxPrs": 7
}'
```

Watch the *Aspire Terminal*. After the 3rd agent call the API process terminates by itself:

```text,nocopy
🤖 Analyzing PR #... with the PrAnalyzer agent
📒 Recorded agent call for PR #... (call #1 in this process).
📒 Recorded agent call for PR #... (call #2 in this process).
💥 CRASH GATE TRIPPED after 3 agent call(s) — killing the process to simulate a crash.
```

Inspect the ledger so far in the *Curl Terminal* — it holds about 2 lines (the call that tripped the gate is recorded only after restart, so it's never duplicated):

```bash,run
cat /root/digest-out/agent-calls.log
```

## 4. Disarm and restart

Stop Aspire in the *Aspire Terminal* with `Ctrl+C`, then disarm the gate and relaunch:

```shell,run,copy
unset CRASH_AFTER_AGENT_CALLS
aspire run
```

Aspire reconnects to the **same Valkey container** (its data volume persists), the workflow engine rehydrates instance `run-crash`, and it **resumes automatically** — you do not call a resume endpoint. In the *Aspire Terminal* you'll see `🤖 Analyzing PR #...` only for the PRs that hadn't finished; the already-analyzed ones stay silent because their results come from durable history.

## 5. Poll until completed

In the *Curl Terminal*:

```bash,run
endpoint="http://localhost:5090"
until curl -s "$endpoint/status/run-crash" | grep -qi '"completed"'; do
  echo "Resuming..."
  sleep 2
done
echo "Workflow completed! ✅"
```

## 6. Durability, proven

Inspect the finished ledger:

```bash,run
cat /root/digest-out/agent-calls.log
```

Confirm:

1. **Exactly 7 lines — one per PR, no duplicate PR numbers.** The calls that completed before the crash were not re-run; their results came from durable history.
2. **A clear timestamp gap** between the pre-crash lines and the rest — the wall-clock cost of the crash and restart, inside a single logical workflow run.

A quick scripted check (run in the *Curl Terminal*):

```bash,run
total=$(grep -c . /root/digest-out/agent-calls.log)
unique=$(cut -f2 /root/digest-out/agent-calls.log | sort -u | grep -c .)
echo "lines=$total unique-PRs=$unique"   # expect both = 7
```

> [!IMPORTANT]
> Click the *Check* button to verify the ledger proves no agent calls were repeated.

---

You've proven the core value: a crash mid-run cost you nothing in repeated LLM calls. In the final challenge you'll inspect the workflow's traces and recap what you learned.
