Welcome to **Make DeepAgents Reliable with Dapr Workflow - Deep Issue Investigation**. In this track you'll run several versions of a CLI tool that uses a [DeepAgents](https://docs.langchain.com/oss/python/deepagents) agent to perform a multi-step investigation for a real GitHub issue and has it write an investigation report — then make that investigation durable to survive a crash.

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

We've picked one issue for this whole track: [dapr/dapr#7326](https://github.com/dapr/dapr/issues/7326) — "Dapr Sidecar still Ready when "failed to load components". This issues has several related PRs, issues, and comment threads.

## 1. Verify the sandbox

Use the **Terminal** window to confirm the Dapr CLI and runtime are ready:

```bash,run
dapr -v
```

> [!NOTE]
> You should see both a **CLI version** and a **Runtime version** listed. If the Runtime version is blank, run `dapr init` below to initialize it. If you run into any other blocking issue during this course, send me [an email](mailto:marc@diagrid.io), and we'll figure it out together.

**GitHub issue & PR data**

> [!IMPORTANT]
> This track works with a pre-fetched GitHub data stored as JSON, so you're not wasting time creating a GitHub token in order to fetch live GitHub data.

If you want, use the *Editor* tab, and navigate to `data/dapr/dapr` to browse through the GitHub data.

## 2. Add your OpenAI API key

Find the `.env` file in the **Editor** and add your key:

```text,nocopy
OPENAI_API_KEY=your_key_here
```

> [!NOTE]
> You'll need a real key from https://platform.openai.com/signup as the agent calls `gpt-4o-mini` in every challenge from here on.

---

You now have a working sandbox and a local GitHub snapshot ready for investigation. Let's move on to challenge 2 where you'll run the agent for the first time.
