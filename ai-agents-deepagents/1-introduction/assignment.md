Welcome to **Make DeepAgents Reliable with Dapr Workflow - Deep Issue Investigation**. In this track you'll build a CLI tool that points a [DeepAgents](https://docs.langchain.com/oss/python/deepagents) agent at a real GitHub issue and has it write an investigation report — then make that investigation durable enough to survive a crash.

In this first challenge you'll set up the sandbox environment and get the CLI tool running against a sample issue. This challenge takes about 5 minutes to complete.

## What is DeepAgents?

DeepAgents is a framework, built on [LangGraph](https://www.langchain.com/langgraph), that gives an LLM three things a plain chat loop doesn't have:

- **Planning** — the agent breaks a vague instruction ("investigate this issue") into its own steps before acting.
- **Tools** — functions the agent can call to read data (in our case, a local GitHub snapshot — never the live API).
- **A virtual filesystem** — a scratchpad the agent reads and writes to as it works, including the final report.

## Why durability matters

A real issue investigation isn't one LLM call — it's dozens of tool calls and reasoning steps, and it can take minutes. All of that lives in memory by default. Kill the process at step 30 of 40 and you lose everything: the scratchpad, the partial report, and every dollar spent on LLM calls so far.

In challenges 3 and 4 you'll back that scratchpad with a **Dapr state store** and wrap the run in a **Dapr Workflow**, so a crashed investigation resumes exactly where it left off instead of starting over.

## The target issue

We've picked one issue for this whole track: [dapr/dapr#1833](https://github.com/dapr/dapr/issues/1833) — "Data corruption in actor/service invocation under high rps." It's closed, has comment threads, and was fixed by a pull request.

## 1. Verify the sandbox

Use the **Terminal** window to confirm the Dapr CLI and runtime are ready:

```bash,run
dapr -v
```

> [!NOTE]
> You should see both a **CLI version** and a **Runtime version** listed. If the Runtime version is blank, run `dapr init` below to initialize it. If you run into any other blocking issue during this course, send me [an email](mailto:marc@diagrid.io), and we'll figure it out together.

In the *Editor* tab, open `track-data-real/dapr/dapr` to browse the snapshot, then open `manifest.json` to see its contents.

This is a static snapshot of issues and pull requests from the real dapr/dapr repository, collected once and checked into this track. The agent only ever reads from this local snapshot.

```text,nocopy
{
  "schema_version": 1,
  "owner": "dapr",
  "repo": "dapr",
  ...
  "seed_issues": [
    1833
  ],
  "counts": {
    "issues": 100,
    "prs": 50
  }
}
```

`seed_issues` confirms #1833 is in the snapshot. `counts` tells you how much data was collected around it.

## 2. Add your OpenAI API key

Find the `.env` file in the **Editor** and add your key:

```env,copy
OPENAI_API_KEY=your_key_here
```

> [!NOTE]
> You'll need a real key from https://platform.openai.com/signup as the agent calls `gpt-4o-mini` in every challenge from here on.

---

You now have a working sandbox and a local GitHub snapshot ready for investigation. Let's move on to challenge 2 where you'll run the agent for the first time.
