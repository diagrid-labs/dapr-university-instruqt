Welcome to the *Making MAF agents reliable with Dapr Workflow* learning track! Agents call large language models, and LLM calls are **slow, costly, and non-deterministic**. When a multi-agent application crashes halfway through, re-running every call from scratch wastes time and money. In this track you'll see how **Dapr Workflow** turns a fleet of **Microsoft Agent Framework (MAF)** agents into a durable, fault-tolerant application. This first challenge will take about 5 minutes to complete.

## 1. The PrDigest application

You'll run **PrDigest**, a .NET Aspire application that triages open pull requests for an open-source maintainer:

- A **`PrAnalyzer`** MAF agent reads each pull request (title, body, diffs, metrics) and writes a plain-English summary and risk rationale.
- A **Dapr Workflow** fans out one checkpointed agent call per pull request, then deterministically ranks the results by a computed risk score.
- A **`Summarize`** MAF agent writes a short headline telling the maintainer where to focus first.
- The workflow writes a ranked Markdown digest (`pr-digest.md`).

The agents talk to OpenAI's `gpt-4o-mini` model through the **Dapr conversation API**, so the application code never holds an API key or a model client directly.

## 2. Why durable execution for agents?

Each `PrAnalyzer` call is an LLM round-trip — the most expensive and slowest part of the run. Dapr Workflow treats every agent call as a **checkpointed activity**: once a call completes, its result is written to durable state. If the process crashes mid-run, the workflow **rehydrates from that state and replays completed calls from history instead of calling the LLM again**. You'll prove this later in the track by crashing the app on purpose.

## 3. Verify the environment

The sandbox comes with Docker, the .NET 10 SDK, the Aspire CLI, and Dapr preinstalled, and the PrDigest source has been cloned for you.

Check the Aspire CLI in the *Terminal*:

```shell,run
aspire --version
```

Confirm Dapr is initialized:

```shell,run
dapr -v
```

Confirm the source was cloned — you should see the `PrDigest` solution folder:

```shell,run
ls ai-agent-tracks-instruqt/MAF/PrDigest
```

> [!IMPORTANT]
> Click the *Check* button to verify the environment is ready before continuing.

---

You now understand what PrDigest does and why durable execution makes its agents reliable. In the next challenge you'll configure your OpenAI key and run the application with Aspire.
