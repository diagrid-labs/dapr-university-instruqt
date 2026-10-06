Welcome to the *Making MAF agents reliable with Dapr Workflow* learning track! Agents call large language models, and LLM calls are **slow, costly, and non-deterministic**. When a multi-agent application crashes halfway through, re-running every call from scratch wastes time and money. In this track you'll see how **Dapr Workflow** turns a fleet of **Microsoft Agent Framework (MAF)** agents into a durable, fault-tolerant application. In this first challenge you'll install the Aspire CLI and verify the sandbox environment. This challenge takes about 5 minutes to complete.

## 1. The PrDigest application

In this course, you'll run **PrDigest**, a .NET Aspire application that triages open pull requests for an open-source maintainer. The application consists of:

- A **`PrAnalyzer`** MAF agent that reads each pull request (title, body, diffs, metrics) and writes a plain-English summary and risk rationale.
- A **Dapr Workflow** that fans out one checkpointed agent call per pull request, then deterministically ranks the results by a computed risk score.
- A **`Summarize`** MAF agent that writes a short headline telling the maintainer where to focus first.
- The workflow writes a ranked Markdown digest (`pr-digest.md`).

The agents talk to OpenAI's `gpt-4.1-mini` model through the **Dapr conversation API**, so the application code never holds an API key or a model client directly.

## 2. Why durable execution for agents?

Each `PrAnalyzer` call is an LLM round-trip — the most expensive and slowest part of the run. Dapr Workflow treats every agent call as a **checkpointed child workflow**: once a call completes, its result is written to durable state. If the process crashes mid-run, the workflow **rehydrates from that state and replays completed calls from history instead of calling the LLM again**. This principle is known as **durable execution**. You'll prove this later in the track by crashing the app on purpose. The Dapr Workflow integration for the Microsoft Agent Framework is provided by Diagrid via the [`Diagrid.AI.Microsoft.AgentFramework`](https://github.com/diagridio/dotnet-ai) package.

Before we can inspect and run the PrDigest application let's verify and configure the sandbox environment.

## 3. Verify the environment

> [!IMPORTANT]
> On the left you should see an *Editor* tab that contains the `PrDigest` solution. On the bottom left you should see an **Aspire Terminal** where you can run commands. If either of those windows is not available (or if you run into a blocking issue during this course), send me [an email](mailto:marc@diagrid.io), and we'll figure it out together.

This sandbox environment comes with Docker, the .NET 10 SDK, and Dapr preinstalled, and the `PrDigest` source has been cloned for you.

You only need to install the Aspire CLI.

1. Let start by installing the Aspire CLI using the **Aspire Terminal**:

  ```shell,run,copy
  curl -sSL https://aspire.dev/install.sh | /bin/bash
  source /root/.bashrc
  ```

  Check that it's working by running:

  ```shell,run,copy
  aspire -v
  ```

2. Use the ***Aspire Terminal*** window to confirm the Dapr CLI and runtime are ready:

```bash,run
dapr -v
```

> [!NOTE]
> You should see both a **CLI version** and a **Runtime version** listed. If the Runtime version is blank, run `dapr init` to initialize it.

## 4. OpenAI API key

The agents reach OpenAI through the Dapr conversation component, which reads the API key from a local secret store. An OpenAI API key has already been provisioned for this sandbox, so you don't need to bring your own.

You should be good to go now! Click the *Check* button to verify the sandbox environment.

---

You now know that Dapr Workflow provides durable execution and makes agents reliable.
In the next challenge you'll explore the PrDigest application in detail.
