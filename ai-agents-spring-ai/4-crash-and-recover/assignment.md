Time to kill the app on purpose and prove it recovers without booking twice. This challenge takes about 8 minutes.

## 1. Restart the app

The Catalyst project and agent already exist from challenge 3, so use the **Terminal** window to just start it again:

```bash,run
diagrid dev run -f dev-spring-ai-crash-recovery.yaml --approve
```

Wait for the app to finish starting up before continuing.

## 2. Book under an id you own

Use the **Terminal 2** window. This time use a fresh id, `trip-42`. The call blocks for about 30 seconds:

```bash,run
curl "http://localhost:8080/crash/book?id=trip-42&reference=ABC123"
```

Switch to **Terminal** and watch for the same log line as before:

```text,nocopy
>>> commitReservation(ABC123) — committing over ~30s. KILL THE APP NOW to test crash recovery (POST /crash/kill, or kill -9). It resumes on restart.
```

## 3. Crash the app mid-call

While that 30 second window is still open, open a third terminal tab if you have one available, or wait for **Terminal 2**'s call to return first and skip ahead. If you can run a second command while the first is still blocking, kill the app now:

```bash,run
curl -X POST "http://localhost:8080/crash/kill"
```

The app process dies. **Terminal 2**'s `curl` sees the connection reset. The workflow instance `trip-42` keeps existing in Catalyst even though the app that started it is gone.

## 4. Restart the app

Use the **Terminal** window:

```bash,run
diagrid dev run -f dev-spring-ai-crash-recovery.yaml --approve
```

The durable runtime resumes instance `trip-42` on its own. The LLM turn that already completed before the crash is not re-executed.

## 5. Re-issue the same request

Use the **Terminal 2** window. Send the **exact same** request, same id, same reference:

```bash,run
curl "http://localhost:8080/crash/book?id=trip-42&reference=ABC123"
```

This attaches to the resumed run instead of starting a new booking. It waits if the run is still committing, or returns immediately if it already finished, and either way you get back:

```text,nocopy
Booking ABC123 confirmed. Confirmation code: BK-...
```

> [!IMPORTANT]
> Compare this confirmation code to the one you'd get from a fresh booking with a different reference. Because it's derived from the reference, a re-attached call always returns the same code. That's the proof the booking was not redone.

## 6. Recap

- The booking agent is a durable `ChatClient`. Every call runs as a Dapr Workflow with no durability code in the agent itself.
- Killing the app mid-call did not lose the workflow. It kept running in Catalyst.
- The instance id you chose is what let the second call attach to the same run instead of colliding with it.
- The confirmation code proved the booking tool ran exactly once, even though you called the endpoint twice.

## 7. Clean up

Stop the app with `Ctrl+C` in the **Terminal** window, then delete the Catalyst project so it doesn't sit around unused:

```bash,run
diagrid project delete spring-ai-crash-recovery
```

---

## Feedback and further learning

Congratulations! 🎉 You've completed the *Making Spring AI Agents Durable with Dapr Workflow* learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving it.

We have more ways for you to learn and share knowledge:

**Try another university track**
- [Making LangGraph agents durable with Dapr Workflow](https://www.diagrid.io/university/ai-agents-langgraph)
- [Deep issue investigation with DeepAgents and Dapr Workflow](https://www.diagrid.io/university/ai-agents-deepagents)

**Read more**
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).
- Read [Announcing Durable Workflow for Agents](https://www.diagrid.io/blog/durable-workflows-ai-agents).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#ai* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.
