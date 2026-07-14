The sandbox for this challenge is being prepared, it should be ready within a few seconds. Once it's ready, click the Start button.

---

In this challenge you'll run a DeepAgent that investigates a real, closed Dapr bug — [dapr/dapr#1833](https://github.com/dapr/dapr/issues/1833), "Data corruption in actor/service invocation under high rps". Our agent will write its findings to a Markdown report.This challenge takes about 5 minutes to complete.

## 1. Inspect the agent

Open `investigate-baseline.py` in the **Editor** window. It's the baseline version; an in-process DeepAgent, no Dapr yet. Look at the `create_deep_agent(...)` call:

```python,nocopy
agent = create_deep_agent(
    model="openai:gpt-4o-mini",
    tools=TOOLS,
    system_prompt=SYSTEM_PROMPT,
    name="issue-investigator",
)
```

`TOOLS` comes from `tools.py` — four functions the agent can call:

- `get_issue(number)` — title, state, labels, body of an issue or PR
- `list_linked_prs(issue_number)` — PRs linked to an issue
- `get_comments(number)` — all comments on an issue or PR
- `search_related_issues(query)` — keyword search across the local snapshot

Every one of these reads from a local JSON file under `/opt/track-data` (see `github_data.py`) — **never** the live GitHub API. The snapshot was collected once, at sandbox-image build time.

`SYSTEM_PROMPT` tells the agent to read the issue and its comments, follow any linked PRs, search for related issues, then write `investigation-<issue-number>.md` using its built-in `write_file` tool — part of the virtual filesystem every DeepAgent gets for free.

## 2. Run the investigation

Use the **Terminal** window to run the agent:

```bash,run
uv run python investigate-baseline.py --issue 1833
```

Watch the terminal: the agent plans its approach, calls tools one at a time, and reasons about what it finds before writing the report. This whole run lives in your terminal's memory — kill the process now and all of that work is gone.

## 3. Read the report

Refresh the *Editor* tab, then navigate to `investigation-1833.md` to open it.

You should see a **Summary**, **Probable Root Cause**, **Related Work**, and **Suggested Next Steps** — built from the issue body, its comments, and the PR that actually fixed it.

## 4. How this works

1. `create_deep_agent()` builds a LangGraph state machine with a planning node, tool-execution nodes, and a virtual filesystem node.
2. The agent receives the investigation prompt and decides which tools to call and in what order.
3. Each tool reads from the local JSON snapshot — no network calls to GitHub.
4. After gathering enough context, the agent calls `write_file` to persist the report into its virtual filesystem, which is then extracted and written to disk.

> [!NOTE]
> This run is entirely in-process — there is no Dapr involved yet. Kill the process partway through and everything is lost. That's the problem challenges 3 and 4 solve.

---

You've now run the DeepAgent and seen it produce a real investigation report. Let's move on to challenge 3 where you'll make the same agent durable by wrapping it in a Dapr Workflow.
