Let's create a Catalyst project and run the booking agent for real. This challenge takes about 7 minutes.

## 1. Create the Catalyst project and agent

Use the **Terminal** window. This creates a project with managed workflows enabled, sets it as your default project for this session, and registers the agent:

```bash,run
diagrid project create spring-ai-crash-recovery --enable-managed-workflow --deploy-managed-kv --wait --use
```

```bash,run
diagrid agent create spring-ai-crash-recovery --wait
```

## 2. Run the agent

```bash,run
diagrid dev run -f dev-spring-ai-crash-recovery.yaml --approve
```

Wait for the app to finish starting up before continuing.

## 3. Book a reservation

Use the **Terminal 2** window. This call blocks for about 30 seconds while the tool "commits" the booking, so don't worry if it hangs there:

```bash,run
curl "http://localhost:8080/crash/book?id=warmup-1&reference=ABC100"
```

Switch back to **Terminal** and watch for the log line:

```text,nocopy
>>> commitReservation(ABC100) — committing over ~30s. KILL THE APP NOW to test crash recovery (POST /crash/kill, or kill -9). It resumes on restart.
```

After about 30 seconds, **Terminal 2** returns the confirmation:

```text,nocopy
Booking ABC100 confirmed. Confirmation code: BK-...
```

## 4. Inspect the run in Catalyst

Open the [Catalyst dashboard](https://catalyst.diagrid.io/agents) and navigate to your `spring-ai-crash-recovery` project. Find the agent and look at its most recent workflow run. You should see the model turn and the `commitReservation` tool call as separate, completed activities.

## 5. Stop the app

Use `Ctrl+C` in the **Terminal** window to stop the agent before moving on. The Catalyst project and agent you created stay in place, you'll reuse them in the next challenge.

---

You've watched a durable booking complete end to end. Let's move on to challenge 4 where you'll crash it on purpose.
