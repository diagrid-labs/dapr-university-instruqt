# Dapr University Tracks

This repo contains content and configuration for the Dapr University tracks hosted with Instruqt. Each track is a self-paced, browser-based learning experience that teaches a specific area of Dapr (workflow, agents, .NET Aspire integration, Catalyst, and Dapr fundamentals) through hands-on challenges. The repository is the source of truth for the track definitions, challenge instructions, setup scripts, and assignment code that Instruqt renders for learners.

You can access the Dapr University lessons here: https://www.diagrid.io/dapr-university

## Prerequisites

The tracks are designed to be consumed through the [Dapr University](https://www.diagrid.io/dapr-university) site — no local installation is required by learners. To preview or edit a track locally you need an [Instruqt](https://instruqt.com/) account with access to the track configuration.

## Running the tracks

The tracks are not intended to be run locally — they are hosted on Instruqt and launched from [Dapr University](https://www.diagrid.io/dapr-university). To make changes, edit the track folder in this repo and push to the relevant Instruqt track.

## Project structure

- `dapr-101/` — Introductory Dapr track.
- `dapr-workflow/` — Dapr Workflow track (durable execution, task chaining, fan-out/fan-in, monitor, external events, child workflows, resiliency, workflow management).
- `dapr-workflow-aspire/` — Dapr Workflow with .NET Aspire track.
- `dapr-dotnet-aspire/` — Dapr + .NET Aspire integration track.
- `dapr-agents/` — Dapr Agents track.
- `dapr-agents-web-context/` — Dapr Agents Advanced track: build a Chainlit-powered expert agent that uses a `before_llm_call` hook to inject fresh Tavily web-search results into every prompt.
- `ai-agents-deepagents/` — Make a [DeepAgents](https://docs.langchain.com/oss/python/deepagents) app durable with Dapr Workflow (Python): crash it mid-investigation and watch it resume from durable state without re-running completed LLM calls.
- `ai-agents-maf/` — Make Microsoft Agent Framework (MAF) agents reliable with Dapr Workflow (.NET Aspire): crash a multi-agent app mid-run and watch it resume from durable state.
- `catalyst-101/` — Introductory Diagrid Catalyst track.
- `tools/track-tester/` — Robot Framework harness that drift-tests the tracks (see below).

## Testing

Because the runnable tracks depend on upstream code (e.g. `dapr/quickstarts`), the assignment instructions can silently drift out of sync with the commands and output learners actually see. To catch this, `tools/track-tester/` holds an end-to-end test harness built on [Robot Framework](https://robotframework.org/): it runs the *actual* commands from each challenge's `assignment.md` and asserts on their output.

Each runnable challenge has a suite next to its assignment, e.g. `dapr-workflow/3-task-chaining/tests/challenge.robot`, with tests tagged per language (`dotnet` / `java` / `python` / `javascript`). A [doc-sync](tools/track-tester/README.md) checker additionally verifies every runnable command in an `assignment.md` is covered by its suite. See [`tools/track-tester/README.md`](tools/track-tester/README.md) for how to run the suites locally.

### GitHub workflows

Three workflows in [`.github/workflows/`](.github/workflows/) run the suites automatically. Each triggers on a daily schedule, on `workflow_dispatch`, and on pull requests that touch the track, the harness, or the workflow file. When a run fails, the `report` job opens (or updates) a `drift-report` issue linking the failing run and the downloadable Robot report.

| Workflow | Track | Schedule (UTC) | Languages / notes |
| --- | --- | --- | --- |
| [`test-dapr-101.yml`](.github/workflows/test-dapr-101.yml) | `dapr-101` | 06:00 daily | dotnet, python, java, javascript |
| [`test-dapr-workflow.yml`](.github/workflows/test-dapr-workflow.yml) | `dapr-workflow` | 06:15 daily | dotnet, java, python (doc-sync + per-language matrix) |
| [`test-dapr-workflow-aspire.yml`](.github/workflows/test-dapr-workflow-aspire.yml) | `dapr-workflow-aspire` | 06:30 daily | .NET 10 + Aspire CLI (harness unit tests + build-and-run) |

---

Join the [Dapr Discord](https://diagrid.ws/dapr-discord) for Q&A and chat with other community members!
