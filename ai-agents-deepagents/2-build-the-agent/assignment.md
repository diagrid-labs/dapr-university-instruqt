In this challenge you'll run a DeepAgent that investigates a real Dapr bug — [dapr/dapr#7326](https://github.com/dapr/dapr/issues/7326), "Dapr Sidecar still Ready when "failed to load components". There's a pre-built agent that writes its findings to a Markdown report that you'll inspect. This challenge takes about 5 minutes to complete.

## 1. Inspect the agent

Open `investigate-baseline.py` in the **Editor** window. It's the baseline version; an in-process DeepAgent, no Dapr yet. Look at the `create_deep_agent(...)` call on line 43:

```python,nocopy
agent = create_deep_agent(
    model="openai:gpt-4.1-mini",
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

Every one of these reads from local JSON files under `data/dapr/dapr`.

`SYSTEM_PROMPT` tells the agent to read the issue and its comments, follow any linked PRs, search for related issues, then write `investigation-<issue-number>-baseline.md` using its built-in `write_file` tool — part of the virtual filesystem every DeepAgent gets for free.

## 2. Run the investigation

Use the **Terminal** window to run the agent:

```bash,run
uv run python investigate-baseline.py --issue 7326
```

Watch the terminal: you'll see updates on retrieved issues, comments and related PRs. This whole run lives in the app's memory: if the process was killed mid-execution, all of the work would be gone.

## 3. Read the report

> [!IMPORTANT]
> Refresh the 'Editor' tab, so it detects the newly created file. You'll find the arrow on the right side of the tree view labelled EDITOR.

Refresh the *Editor* tab since a new file has been created, then navigate to `investigation-7326-baseline.md` to open it.

You should see a **Summary**, **Probable Root Cause**, **Related Work**, and **Suggested Next Steps** — built from the issue body, its comments, and the PR that actually fixed it.

## 4. How this works

1. `create_deep_agent()` builds a LangGraph state machine with a planning node, tool-execution nodes, and a virtual filesystem node.
2. The agent receives the investigation prompt and decides which tools to call and in what order.
3. Each tool reads from the local JSON snapshot — no network calls to GitHub.
4. After gathering enough context, the agent calls `write_file` to persist the report into its virtual filesystem, which is then extracted and written to disk.

---

You've now run the DeepAgent and seen it produce a real investigation report. Let's move on to challenge 3 where you'll make the same agent durable by wrapping it in a Dapr Workflow.
