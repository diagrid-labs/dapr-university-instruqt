Time to bring the app back and watch it finish the job. This challenge takes about 6 minutes.

## 1. Remove the crash

Open `src/main/java/io/diagrid/quickstart/springai/eventplanner/EventPlannerTools.java` in the **Editor** and comment out the crash line inside `stepTwoCompare`:

```java,nocopy
// Runtime.getRuntime().halt(1); // 💥 Comment out this line before the second run — then re-run without re-triggering /run and watch the workflow resume.
```

## 2. Restart the app

Use the **Terminal** window:

```bash,run
diagrid dev run -f dev-spring-ai-event-planner.yaml --approve
```

## 3. Watch it recover

Don't call `curl` again. Just watch the **Terminal** output:

```text,nocopy
>>> TOOL 2: Comparing venues...
>>> TOOL 2 COMPLETE: Grand Ballroom is the best option
>>> TOOL 3: Confirming booking...
>>> TOOL 3 COMPLETE: Booking confirmed for Grand Ballroom
```

> [!IMPORTANT]
> Notice `TOOL 1` does **not** print again. Its result already exists in the workflow's history from before the crash, so it's replayed instead of re-executed. The workflow picks up exactly at `step_two_compare`, using the same input it was given the first time.

The original `curl` request from challenge 3 already returned (or errored out) when the process died, so there's no HTTP response to look at here. The proof is the workflow itself finishing on its own.

## 4. Inspect the run in Catalyst

Open the [Catalyst dashboard](https://catalyst.diagrid.io/agents) and navigate to your `spring-ai-quickstart` project. Find the `spring-ai-event-planner` agent and look at its workflow run. You should see all three tool calls, with the first one completed before the crash and the other two completed after the restart.

## 5. Recap

- The event planner agent is a durable `ChatClient`. Every call runs as a Dapr Workflow with no durability code in the agent itself.
- Killing the process mid-tool did not lose the workflow. It kept existing in Catalyst.
- Restarting the app was enough to resume it. No new HTTP request was needed.
- `step_one_search` was replayed from history, not re-executed, which only matters because it's side-effect-free. A tool with a real effect would need its own idempotency strategy.

## 6. Clean up

Stop the app with `Ctrl+C` in the **Terminal** window, then delete the Catalyst project so it doesn't sit around unused:

```bash,run
diagrid project delete spring-ai-quickstart
```

---

## Feedback and further learning

Congratulations! 🎉 You've completed the *Making Spring AI Agents Durable with Dapr Workflow* learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving it.

We have more ways for you to learn and share knowledge:

**Try another university track**
- [Making Spring AI agents durable with idempotent retries](https://www.diagrid.io/university/ai-agents-spring-ai)
- [Making LangGraph agents durable with Dapr Workflow](https://www.diagrid.io/university/ai-agents-langgraph)
- [Deep issue investigation with DeepAgents and Dapr Workflow](https://www.diagrid.io/university/ai-agents-deepagents)

**Read more**
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).
- Read [Announcing Durable Workflow for Agents](https://www.diagrid.io/blog/durable-workflows-ai-agents).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#ai* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.
