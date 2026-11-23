# Durable execution

In this lab, you'll start a workflow, crash the app in the middle of it, and watch the workflow carry on from the last completed step after a restart. This hands-on lab takes about 7 minutes to complete.

## 1. Workflows and activities

The demos in this track tell one story. The **engineering** console of the starship *ISV Meridian* prepares each warp jump with a workflow. In this lab the workflow `ChargeWarpCoreWorkflow` charges the warp core in five stages. It calls one activity, `ChargeStageActivity`, five times in a plain loop. Each stage takes about three seconds and then logs a line.

Every workflow app has two building blocks:

- **The workflow** decides what happens in which order. It doesn't do the work itself.
- **An activity** does the work: it can be slow, call other services or write to a database.

A workflow is ordinary code in your app. The Dapr sidecar runs it: it schedules each activity, saves the workflow's history in a state store, and replays the code from that history when the app comes back after a crash. In this track the state store is the Redis container that `dapr init` started.

Use the **Editor** tab to open the demo folder of your language: `dotnet/Demo1-DurableExecution`, `python/demo1-durable-execution`, `java/demo1-durable-execution` or `typescript/demo1-durable-execution`. The `engineering` app has two endpoints: `POST /jumps` starts a workflow, and the `jumpId` you send becomes the workflow's instance ID. `GET /jumps/{jumpId}` returns its status and result.

## 2. Run the demo

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `workflow` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

```bash,run
cd /root/university-labs/workflow
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo1-DurableExecution` for .NET, `demo1-durable-execution` for Python, Java and TypeScript. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo1-DurableExecution* folder:

```bash,run
cd dotnet/Demo1-DurableExecution
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo1-durable-execution* folder:

```bash,run
cd python/demo1-durable-execution
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo1-durable-execution* folder:

```bash,run
cd java/demo1-durable-execution
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>TypeScript</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *typescript/demo1-durable-execution* folder:

```bash,run
cd typescript/demo1-durable-execution
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!NOTE]
> When the app starts, the Editor shows a popup saying *Your application running on port `<number>` is available*. Close the popup, or click the settings gear to dismiss it. There is no UI to open, so don't click *Open in Browser*.

> [!IMPORTANT]
> Wait until the application is running before continuing. The Java application can take a little longer to start.
>
> Open the **Dev Dashboard** tab and check the application health on the **Applications** page: `engineering` is ready when the **Health** column shows a green dot. You can also inspect the output of the **Dapr CLI** window.

The **Dapr CLI** window should show this line when the sidecar has started, and your application's logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "engineering". HTTP Port: 3530. gRPC Port: 50330
```

## 3. Start a jump

The next step needs quick hands, so get ready first. On the **Logs** page of the **Dev Dashboard** tab, select `engineering` and search for `jump-001`. The same lines also appear in the **Dapr CLI** window.

Use the **curl** window to start a jump with the ID `jump-001`:

```bash,run
curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq
```

Expected output:

```json,nocopy
{
  "jumpId": "jump-001"
}
```

Then click in the **Dapr CLI** window, so it is ready for the next step. `engineering` logs one line when the workflow starts and one line every three seconds after that:

```text,nocopy
== APP - engineering == engineering jump-001 charge sequence started
== APP - engineering == engineering charge stage 1/5 complete for jump-001
== APP - engineering == engineering charge stage 2/5 complete for jump-001
```

The lines above show only the message. In the real log, Python and Java put their own logger prefix in front of it, .NET writes an `info:` line followed by the message on a line of its own, and the TypeScript SDK logs a few lines of its own between them.

## 4. Crash the ship

> [!IMPORTANT]
> Right after the `charge stage 2/5 complete` line appears, press `Ctrl+C` in the **Dapr CLI** window.

That stops the app and its sidecar while stage 3 is running. In Python you may still see `charge stage 3/5 complete` while the app shuts down: the activity finished, but its result never reached the sidecar.

If you were a little late and stage 3 or 4 also completed before the crash, that's fine. Fewer stages are left after the restart, and the rest of the lab works the same way.

### If the jump finished before the crash

If `charge stage 5/5 complete` appeared before you pressed `Ctrl+C`, there was nothing left to recover. Start the app again with `dapr run -f .` in the **Dapr CLI** window and wait until it is running. Then use the **curl** window to start a new jump with a new ID:

```bash,run
curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-002"}' | jq
```

Press `Ctrl+C` in the **Dapr CLI** window right after `charge stage 2/5 complete for jump-002`, and read `jump-002` for `jump-001` in the rest of this lab.

## 5. Start the app again

Use the **Dapr CLI** window to start the app again, from the same folder:

```bash,run
dapr run -f .
```

Don't send another `curl`. Within a few seconds of the app being ready, the log carries on where the workflow stopped:

```text,nocopy
== APP - engineering == engineering charge stage 3/5 complete for jump-001
== APP - engineering == engineering charge stage 4/5 complete for jump-001
== APP - engineering == engineering charge stage 5/5 complete for jump-001
```

Stages 1 and 2 are not in the new log, and neither is `charge sequence started`.

Use the **curl** window to check the jump:

```bash,run
curl -s http://localhost:5301/jumps/jump-001 | jq
```

Expected output. If the status is still `RUNNING`, wait a few seconds and run the command again:

```json,nocopy
{
  "jumpId": "jump-001",
  "status": "COMPLETED",
  "output": {
    "jumpId": "jump-001",
    "coreCharged": true
  }
}
```

If you used `jump-002`, check that one instead:

```bash,run
curl -s http://localhost:5301/jumps/jump-002 | jq
```

Now open the **Dev Dashboard** tab and go to the **Workflows** page. It lists the `ChargeWarpCoreWorkflow` run with the ID `jump-001` and its status. Select it to see its event history, its input and its output. The dashboard reads them from the same Redis state store that the sidecar writes to.

## 6. What happened

- **Completed stages didn't run again.** Every time an activity finishes, the sidecar records its result in the workflow's history in the state store. Each `await` (or `yield` in Python and TypeScript) on an activity is a checkpoint. Stages 1 and 2 were in the history before the crash, so they were not repeated.
- **The stage that was running did run again.** Stage 3 had not reported back when the app stopped, so after the restart the sidecar sent it to the app again. Activities run at least once, so they should be safe to repeat.
- **The workflow code itself ran again, from the top.** After the restart the sidecar replayed `ChargeWarpCoreWorkflow` to rebuild where it was. On a replay the SDK hands the stored results of stages 1 and 2 straight back instead of running those activities. The `charge sequence started` line is written with a replay-safe logger, or behind an *is replaying* check, so it doesn't appear a second time even though that line of code ran again.

> [!NOTE]
> Expand the language-specific instructions to see the loop in the workflow code.

<details>
   <summary><b>.NET</b></summary>

`dotnet/Demo1-DurableExecution/Engineering/ChargeWarpCoreWorkflow.cs`:

```csharp,nocopy
public override async Task<ChargeResult> RunAsync(WorkflowContext context, Jump jump)
{
    // During a replay this method runs again. A replay-safe logger skips its lines then.
    var logger = context.CreateReplaySafeLogger<ChargeWarpCoreWorkflow>();
    logger.LogInformation("engineering {JumpId} charge sequence started", jump.JumpId);

    for (var stage = 1; stage <= Stages; stage++)
    {
        // Each await is a checkpoint: the activity's result is stored in the workflow history.
        // On a replay a stage that already finished returns its stored result straight away.
        await context.CallActivityAsync(nameof(ChargeStageActivity), new ChargeStage(jump.JumpId, stage));
    }

    return new ChargeResult(jump.JumpId, CoreCharged: true);
}
```

</details>

<details>
   <summary><b>Python</b></summary>

`python/demo1-durable-execution/engineering/workflow.py`:

```python,nocopy
@wfr.workflow(name="ChargeWarpCoreWorkflow")
def charge_warp_core_workflow(ctx: wf.DaprWorkflowContext, jump: dict):
    jump_id = jump["jumpId"]
    # During a replay this line runs again, so only log when the code is not replaying.
    if not ctx.is_replaying:
        logger.info("engineering %s charge sequence started", jump_id)

    for stage in range(1, STAGES + 1):
        # Each yield is a checkpoint: the activity's result is stored in the workflow history.
        # On a replay a stage that already finished returns its stored result straight away.
        yield ctx.call_activity(charge_stage_activity, input={"jumpId": jump_id, "stage": stage})

    return {"jumpId": jump_id, "coreCharged": True}
```

</details>

<details>
   <summary><b>Java</b></summary>

`java/demo1-durable-execution/engineering/src/main/java/io/diagrid/university/workflow/engineering/ChargeWarpCoreWorkflow.java`:

```java,nocopy
@Override
public WorkflowStub create() {
    return ctx -> {
        Jump jump = ctx.getInput(Jump.class);
        // ctx.getLogger() is replay-safe: it skips its lines while the workflow replays.
        ctx.getLogger().info("engineering {} charge sequence started", jump.jumpId());

        for (int stage = 1; stage <= STAGES; stage++) {
            // Each await() is a checkpoint: the activity's result is stored in the workflow
            // history. On a replay a stage that already finished returns its stored result
            // straight away.
            ctx.callActivity("ChargeStageActivity", new ChargeStageActivity.ChargeStage(jump.jumpId(), stage))
                    .await();
        }

        ctx.complete(new ChargeResult(jump.jumpId(), true));
    };
}
```

</details>

<details>
   <summary><b>TypeScript</b></summary>

`typescript/demo1-durable-execution/engineering/workflow.ts`:

```typescript,nocopy
export async function* chargeWarpCoreWorkflow(ctx: WorkflowContext, jump: Jump) {
  // During a replay this line runs again, so only log when the code is not replaying.
  if (!ctx.isReplaying()) {
    console.log(`engineering ${jump.jumpId} charge sequence started`);
  }

  for (let stage = 1; stage <= STAGES; stage++) {
    const charge: ChargeStage = { jumpId: jump.jumpId, stage };
    // Each yield is a checkpoint: the activity's result is stored in the workflow history.
    // On a replay a stage that already finished returns its stored result straight away.
    // Call the activity by its registered name: passing the function would use its JS name.
    yield ctx.callActivity("ChargeStageActivity", charge);
  }

  return { jumpId: jump.jumpId, coreCharged: true };
}
```

</details>

Because the workflow code is replayed, it must be **deterministic**: every replay has to make the same calls in the same order. So the workflow never reads the clock, makes random numbers, does I/O or sleeps. The three-second wait is inside the activity, which is where that kind of work belongs.

The app also has no database code. The state store component is only used by the sidecar, which saves and loads the workflow history.

## 7. Clean up

The workflow history stays in Redis after the app stops, and every demo in this track uses the same app ID, `engineering`. The `dapr workflow` commands of the Dapr CLI talk to the running sidecar, so clean up before you stop the app.

Use the **curl** window to purge the history of `jump-001`, which has finished:

```bash,run
dapr workflow purge jump-001 -a engineering
```

If you used `jump-002`, purge it too:

```bash,run
dapr workflow purge jump-002 -a engineering
```

## 8. Stop the applications

Use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

---

The workflow survived a crash: it carried on from the last completed stage, without a new request and without any database code in the app.

## What's next?

In the next lab you'll chain four activities in a row, with the result of each one passed as the input of the next: the task chaining pattern.
