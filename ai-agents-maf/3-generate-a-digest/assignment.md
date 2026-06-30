In this challenge you'll start a digest run, watch it complete, and read the ranked pull-request digest the MAF agents produced. It will take about 5 minutes.

Make sure `aspire run` from the previous challenge is still running in the *Aspire Terminal* and all resources show **Running** in the *Aspire* tab.

## 1. Start a digest run

The API service exposes a `/start` endpoint on the fixed port `5090`. In the *Curl Terminal*, schedule a workflow over the `dapr/dapr` pull requests:

```curl,run
curl -X POST "http://localhost:5090/start" -H "Content-Type: application/json" -d '{
  "id": "run-1",
  "repo": "dapr/dapr",
  "maxPrs": 7
}'
```

The response echoes the workflow instance id:

```json,nocopy
{ "instanceId": "run-1" }
```

Behind the scenes the workflow fans out one `PrAnalyzer` agent call per pull request — these are the LLM round-trips — then ranks the results and asks the `Summarize` agent for a headline.

## 2. Poll until the workflow completes

The agent calls take a little time. Poll the `/status/{instanceId}` endpoint until the run reports completed. In the *Curl Terminal*:

```bash,run
endpoint="http://localhost:5090"
until curl -s "$endpoint/status/run-1" | grep -qi '"completed"'; do
  echo "Workflow running..."
  sleep 2
done
echo "Workflow completed! ✅"
```

> [!NOTE]
> Watch the *Aspire Terminal* while it runs — you'll see a `🤖 Analyzing PR #...` line for each pull request as its agent call executes.

## 3. Read the digest

The workflow writes a ranked Markdown digest to the output directory you set earlier (`/root/digest-out`). Read it in the *Curl Terminal*:

```bash,run
cat /root/digest-out/pr-digest.md
```

The digest ranks the pull requests by a computed **risk score** and includes, for each one:

- Rank, PR number, and title
- Risk score and flags (e.g. `many-files`, `large-diff`, `no-tests`, `no-linked-issue`)
- A summary and risk rationale — written by the `PrAnalyzer` agent
- The linked issue, if any

At the top is the headline written by the `Summarize` agent. The exact pull requests and scores depend on the bundled data snapshot.

> [!IMPORTANT]
> Click the *Check* button to verify the digest was generated.

---

You've run an agentic workflow end-to-end: each row in that digest cost a real LLM call. Next you'll crash the app mid-run and prove those calls are **not** repeated on resume.
