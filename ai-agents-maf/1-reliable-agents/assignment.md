Welcome to the *Making MAF agents reliable with Dapr Workflow* learning track! Agents call large language models, and LLM calls are **slow, costly, and non-deterministic**. When a multi-agent application crashes halfway through, re-running every call from scratch wastes time and money. In this track you'll see how **Dapr Workflow** turns a fleet of **Microsoft Agent Framework (MAF)** agents into a durable, fault-tolerant application. In this first challenge you'll install the Aspire CLI and configure your own OpenAI API key. This challenge takes about 5 minutes to complete.

## 1. The PrDigest application

In this course, you'll run **PrDigest**, a .NET Aspire application that triages open pull requests for an open-source maintainer. The application consists of:

- A **`PrAnalyzer`** MAF agent reads each pull request (title, body, diffs, metrics) and writes a plain-English summary and risk rationale.
- A **Dapr Workflow** fans out one checkpointed agent call per pull request, then deterministically ranks the results by a computed risk score.
- A **`Summarize`** MAF agent writes a short headline telling the maintainer where to focus first.
- The workflow writes a ranked Markdown digest (`pr-digest.md`).

The agents talk to OpenAI's `gpt-4o-mini` model through the **Dapr conversation API**, so the application code never holds an API key or a model client directly.

## 2. Why durable execution for agents?

Each `PrAnalyzer` call is an LLM round-trip — the most expensive and slowest part of the run. Dapr Workflow treats every agent call as a **checkpointed child workflow**: once a call completes, its result is written to durable state. If the process crashes mid-run, the workflow **rehydrates from that state and replays completed calls from history instead of calling the LLM again**. This principle is known as **durable execution**. You'll prove this later in the track by crashing the app on purpose.

## 3. Verify the environment

This sandbox environment comes with Docker, the .NET 10 SDK, and Dapr preinstalled, and the `PrDigest` source has been cloned for you.

> [!IMPORTANT]
> On the left you should see an *Editor* tab that contains `PrDigest` solution. On the bottom left you should see a *Terminal* where you can type commands. If either of those windows is not available (or if you run into a blocking issue during this course), send me [an email](mailto:marc@diagrid.io), and we'll figure it out together.

You only need to install the Aspire CLI and set your OpenAI API key as an environment variable.

Let start by installing the Aspire CLI using the *Terminal*:

```shell,run,copy
curl -sSL https://aspire.dev/install.sh | /bin/bash
source /root/.bashrc
```

## 4. Add your OpenAI API key

The agents reach OpenAI through the Dapr conversation component, which reads the key from a local secret store (`PrDigest.AppHost/secrets.json`). That file is git-ignored and not part of the clone, so create it from the template. 

In the *Aspire Terminal* run:

```shell,run,copy
cp PrDigest.AppHost/secrets.example.json PrDigest.AppHost/secrets.json
```

Refresh the *Editor* tab with the circular arrow button, so it can show the newly created file, open `PrDigest.AppHost/secrets.json` and paste your key so it looks like this:

```json,nocopy
{
  "openai-api-key": "sk-...your-key..."
}
```

The file should auto-save.

You should be good to go now!

---

You now know that Dapr Workflow provides durable execution and makes agents reliable. In the next challenge you'll configure your OpenAI key and run the application with Aspire.
