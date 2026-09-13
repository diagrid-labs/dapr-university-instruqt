Let's create a Catalyst project and watch the event planner crash on purpose. This challenge takes about 6 minutes.

## 1. Create the Catalyst project and agent

Use the **Terminal** window. This creates a project with managed workflows enabled, sets it as your default project for this session, and registers the agent:

```bash,run
diagrid project create spring-ai-quickstart --enable-managed-workflow --deploy-managed-kv --wait --use
```

```bash,run
diagrid agent create spring-ai-event-planner --wait
```

> [!NOTE]
> `diagrid agent create` isn't optional here. It creates the App ID the agent registry needs, and `diagrid dev run` would otherwise fail to register the agent against a connection that doesn't exist yet.

## 2. Run the agent

```bash,run
diagrid dev run -f dev-spring-ai-event-planner.yaml --approve
```

Wait for the app to finish starting up before continuing.

## 3. Trigger the agent

Use the **Terminal 2** window:

```bash,run
curl -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Find a venue in Austin for a company gala"}'
```

## 4. Watch it crash

Switch to **Terminal**. You'll see:

```text,nocopy
>>> TOOL 1: Searching venues in 'Austin'...
>>> TOOL 1 COMPLETE: Found 3 venues
>>> TOOL 2: Comparing venues...
```

Then the process exits. **Terminal 2**'s `curl` call never returns a result, because the app died mid-request.

> [!IMPORTANT]
> This is expected. The workflow itself is safe in Catalyst even though the process that started it is gone.

## 5. How this works

1. `step_one_search` completed and was checkpointed before the crash.
2. `step_two_compare` started, logged its first line, then halted the JVM.
3. The workflow instance behind this run still exists in Catalyst, holding the history of what already completed.
4. Nothing about the crash lost the completed step. It's sitting there, waiting for the app to come back.

---

You've watched a durable workflow survive the process that created it. Let's move on to challenge 4 where you'll bring the app back and watch it finish the job.
