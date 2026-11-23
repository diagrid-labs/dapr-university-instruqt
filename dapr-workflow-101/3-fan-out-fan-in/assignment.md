# Fan-out/fan-in

In this lab, you'll run a workflow that starts five activities at the same time and waits for all of them. This hands-on lab takes about 6 minutes to complete.

## Before you start

The terminals, and the applications running in them, stay as they are when you move between labs. Open the **Dev Dashboard** tab and look at which applications are running. If any are, for example `engineering` from the previous lab, use the **Dapr CLI** window to stop them by pressing `Ctrl+C`. They use the same ports as the app in this lab. Then go back to the **Editor** tab.

## 1. The scan

Before the jump, the **engineering** console scans the route with five sensor arrays. The scans don't depend on each other, so there is no reason to run them one after another. In this lab the workflow `RouteScanWorkflow` starts all five scans at once, then waits until every one is done and combines the results. This is the **fan-out/fan-in** pattern:

- **Fan-out:** the workflow schedules all five activity calls without waiting for each one in turn.
- **Fan-in:** it then waits for all of them at once, and works out `routeRisk`, the highest hazard score, and a `verdict`: `CLEAR` below 50, otherwise `HAZARDOUS`.

`ScanSectorActivity` takes the name of an array, scans for 2 seconds and returns a hazard score:

| Array | Hazard |
|---|---|
| `alpha` | 12 |
| `beta` | 7 |
| `gamma` | 31 |
| `delta` | 4 |
| `epsilon` | 18 |

The scores are fixed, so every run and every language gets the same result.

Use the **Editor** tab to open the demo folder of your language: `dotnet/Demo3-FanOutFanIn`, `python/demo3-fan-out-fan-in`, `java/demo3-fan-out-fan-in` or `typescript/demo3-fan-out-fan-in`. The `engineering` app has the same two endpoints as before. This demo accepts a `destination` like the other demos, but ignores it.

## 2. Run the demo

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `workflow` folder first:

```bash,run
cd /root/university-labs/workflow
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo3-FanOutFanIn` for .NET, `demo3-fan-out-fan-in` for Python, Java and TypeScript. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo3-FanOutFanIn* folder:

```bash,run
cd dotnet/Demo3-FanOutFanIn
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo3-fan-out-fan-in* folder:

```bash,run
cd python/demo3-fan-out-fan-in
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo3-fan-out-fan-in* folder:

```bash,run
cd java/demo3-fan-out-fan-in
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>TypeScript</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *typescript/demo3-fan-out-fan-in* folder:

```bash,run
cd typescript/demo3-fan-out-fan-in
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Wait until the application is running before continuing. The Java application can take a little longer to start.
>
> Open the **Dev Dashboard** tab and check the application health on the **Applications** page: `engineering` is ready when the **Health** column shows a green dot. You can also inspect the output of the **Dapr CLI** window.

## 3. Start a jump

Use the **curl** window to start `jump-001`, wait 5 seconds and check the result. The three commands are in one block, so they run back to back:

```bash,run
curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq
sleep 5
curl -s http://localhost:5301/jumps/jump-001 | jq
```

Expected output:

```json,nocopy
{
  "jumpId": "jump-001"
}
{
  "jumpId": "jump-001",
  "status": "COMPLETED",
  "output": {
    "routeRisk": 31,
    "verdict": "CLEAR"
  }
}
```

If the status is still `RUNNING`, wait a moment and run the status command again:

```bash,run
curl -s http://localhost:5301/jumps/jump-001 | jq
```

Open the **Dev Dashboard** tab, go to the **Workflows** page and select the `jump-001` instance of `RouteScanWorkflow`. Look at the times of the events in its **Event history**:

- Five `TaskScheduled` events for `ScanSectorActivity`, all at about the same moment. Expand one to see which sensor array it scans.
- Five `TaskCompleted` events, about two seconds later. Expand one to see the hazard score of its array. The order of these events can differ from the order of the `TaskScheduled` events.
- An `ExecutionCompleted` event with the workflow's output.

Two things to notice:

1. **The whole scan takes about 2 seconds, not 10.** All five scans are scheduled before any of them completes. Five scans of 2 seconds in a row would take 10 seconds, but the status was already `COMPLETED` after 5. The runtime runs the five activities in parallel, and the workflow continues as soon as the slowest one is done.
2. **The order of the `TaskCompleted` events changes from run to run.** Whichever scan finishes first is recorded first. The output doesn't change, because the workflow computes it from all five results: the highest score (`gamma`, 31) and the verdict.

## 4. Look at the workflow code

The fan-out is a loop that calls five activities without waiting for any of them. The fan-in is a single wait for all of the calls. Expand the language-specific instructions to see both parts.

<details>
   <summary><b>.NET</b></summary>

`dotnet/Demo3-FanOutFanIn/Engineering/RouteScanWorkflow.cs`:

```csharp,nocopy
// Fan-out: CallActivityAsync returns a task straight away. ToArray() starts all five.
var scans = Arrays
    .Select(array => context.CallActivityAsync<SectorScan>(nameof(ScanSectorActivity), array))
    .ToArray();

// Fan-in: continue when every scan has finished.
var results = await Task.WhenAll(scans);
```

</details>

<details>
   <summary><b>Python</b></summary>

`python/demo3-fan-out-fan-in/engineering/workflow.py`:

```python,nocopy
# Fan-out: call_activity returns a task straight away, nothing has finished yet.
scans = [
    ctx.call_activity(scan_sector_activity, input=array)
    for array in ("alpha", "beta", "gamma", "delta", "epsilon")
]

# Fan-in: continue when every scan has finished. The results keep the order of the list.
results = yield wf.when_all(scans)
```

</details>

<details>
   <summary><b>Java</b></summary>

`java/demo3-fan-out-fan-in/engineering/src/main/java/io/diagrid/university/workflow/engineering/RouteScanWorkflow.java`:

```java,nocopy
// Fan-out: callActivity returns a task straight away, nothing has finished yet.
List<Task<SectorScan>> scans = List.of("alpha", "beta", "gamma", "delta", "epsilon").stream()
        .map(array -> ctx.callActivity("ScanSectorActivity", array, SectorScan.class))
        .toList();

// Fan-in: continue when every scan has finished. The results keep the order of the list.
List<SectorScan> results = ctx.allOf(scans).await();
```

</details>

<details>
   <summary><b>TypeScript</b></summary>

`typescript/demo3-fan-out-fan-in/engineering/workflow.ts`:

```typescript,nocopy
// Fan-out: callActivity returns a task straight away, nothing has finished yet.
const scans = ["alpha", "beta", "gamma", "delta", "epsilon"].map((array) =>
  ctx.callActivity("ScanSectorActivity", array),
);

// Fan-in: continue when every scan has finished. The results keep the order of the list.
const results: SectorScan[] = yield ctx.whenAll(scans);
```

</details>

The results keep the order in which the scans were scheduled, not the order in which they finished. That is why the output is the same on every run.

## 5. Start a second jump

Use the **curl** window to start `jump-002` and check it after 5 seconds:

```bash,run
curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002"}' | jq
sleep 5
curl -s http://localhost:5301/jumps/jump-002 | jq
```

Expected output: the same as for `jump-001`, with the new ID.

```json,nocopy
{
  "jumpId": "jump-002"
}
{
  "jumpId": "jump-002",
  "status": "COMPLETED",
  "output": {
    "routeRisk": 31,
    "verdict": "CLEAR"
  }
}
```

Select the `jump-002` instance on the **Workflows** page and compare the order of its five `TaskCompleted` events with the first run. They are likely in a different order, and the result is the same.

## 6. Clean up

The workflow history stays in Redis after the app stops, and every demo in this track uses the same app ID, `engineering`. Use the **curl** window to purge the history of the finished jumps while the app is still running:

```bash,run
dapr workflow purge --all -a engineering
```

## 7. Stop the applications

Use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

---

You ran five activities at the same time and combined their results with a few lines of ordinary code.

## What's next?

In the next lab you'll check on something over time: the monitor pattern, with a durable timer and a workflow that restarts itself.
