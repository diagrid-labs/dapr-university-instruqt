# Monitor

In this lab, you'll run a workflow that checks the warp core until it is stable, waits between checks, and restarts itself. This hands-on lab takes about 6 minutes to complete.

## Before you start

The terminals, and the applications running in them, stay as they are when you move between labs. Open the **Dev Dashboard** tab and look at which applications are running. If any are, for example `engineering` from the previous lab, use the **Dapr CLI** window to stop them by pressing `Ctrl+C`. They use the same ports as the app in this lab. Then go back to the **Editor** tab.

## 1. The monitor

Before the jump, the **engineering** console watches the warp-core temperature until it is stable. In this lab the workflow `CoreStabilityWorkflow` does that. This is the **monitor** pattern: check something, wait, check again, until a condition is met.

`ReadCoreTempActivity` takes the check number and returns the temperature in kelvin. The values are fixed, so every run and every language gets the same sequence:

| Check | Temperature |
|---|---|
| 1 | 1240K |
| 2 | 1180K |
| 3 | 1120K |
| 4 | 1060K |
| 5 | 1000K |

Each run of the workflow is one check:

1. It reads the temperature. At 1000K or lower the core is stable and the workflow returns `{"stable": true, ...}`.
2. If not, it waits on a **durable timer** of 5 seconds. The timer is stored by Dapr, not held in the app's memory, so it survives a restart of the app.
3. Then it calls **continue-as-new** with the next check number. That restarts the workflow with new input and an empty history.
4. The guard every monitor needs: at check 10 the workflow gives up and returns `{"stable": false, ...}`. With this fixed sequence it never triggers.

Use the **Editor** tab to open the demo folder of your language: `dotnet/Demo4-Monitor`, `python/demo4-monitor`, `java/demo4-monitor` or `typescript/demo4-monitor`. The `engineering` app has the same two endpoints as before. This demo accepts a `destination` like the other demos, but ignores it.

## 2. Run the demo

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `workflow` folder first:

```bash,run
cd /root/university-labs/workflow
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo4-Monitor` for .NET, `demo4-monitor` for Python, Java and TypeScript. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo4-Monitor* folder:

```bash,run
cd dotnet/Demo4-Monitor
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo4-monitor* folder:

```bash,run
cd python/demo4-monitor
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo4-monitor* folder:

```bash,run
cd java/demo4-monitor
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>TypeScript</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *typescript/demo4-monitor* folder:

```bash,run
cd typescript/demo4-monitor
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

The **Dapr CLI** window should show this line when the sidecar has started, and your application's logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "engineering". HTTP Port: 3530. gRPC Port: 50330
```

## 3. Start a jump

Open the **Dev Dashboard** tab, go to the **Logs** page, select `engineering` and search for `core temperature`. The same lines also appear in the **Dapr CLI** window.

Use the **curl** window to start `jump-001`, wait 7 seconds and check the status. The three commands are in one block, so they run back to back:

```bash,run
curl -s -X POST http://localhost:5301/jumps -H 'Content-Type: application/json' -d '{"jumpId": "jump-001"}' | jq
sleep 7
curl -s http://localhost:5301/jumps/jump-001 | jq
```

Expected output:

```json,nocopy
{
  "jumpId": "jump-001"
}
{
  "jumpId": "jump-001",
  "status": "RUNNING",
  "output": null
}
```

The monitor needs about 20 seconds in total. While it runs, the status is `RUNNING`, also in the moments between two checks. `engineering` logs one line about every 5 seconds:

```text,nocopy
== APP - engineering == engineering core temperature check 1: 1240K
== APP - engineering == engineering core temperature check 2: 1180K
== APP - engineering == engineering core temperature check 3: 1120K
== APP - engineering == engineering core temperature check 4: 1060K
== APP - engineering == engineering core temperature check 5: 1000K
```

The lines above show only the message. In the real log, Python and Java put their own logger prefix in front of it, and .NET writes an `info:` line followed by the message on a line of its own.

When check 5 is logged, use the **curl** window to check the status again. If it's still `RUNNING`, run the command again:

```bash,run
curl -s http://localhost:5301/jumps/jump-001 | jq
```

Expected output:

```json,nocopy
{
  "jumpId": "jump-001",
  "status": "COMPLETED",
  "output": {
    "stable": true,
    "checks": 5,
    "coreTempK": 1000
  }
}
```

Two things to notice:

1. **The ID stays `jump-001`.** Every check is a new run of the workflow, but the instance ID stays the same, so you use the same status URL from start to finish.
2. **The core is stable at check 5.** 1000K is the first temperature that is at or below the limit, so the workflow returns instead of waiting again.

## 4. Look at the workflow code

The workflow has four parts to look at: the check, the guard, the durable timer and the continue-as-new call. Expand the language-specific instructions to see them.

<details>
   <summary><b>.NET</b></summary>

`dotnet/Demo4-Monitor/Engineering/CoreStabilityWorkflow.cs`:

```csharp,nocopy
var coreTempK = await context.CallActivityAsync<int>(nameof(ReadCoreTempActivity), jump.Check);

if (coreTempK <= 1000)
{
    return new CoreStability(true, jump.Check, coreTempK);
}

// The guard every monitor needs: give up after 10 checks.
if (jump.Check == 10)
{
    return new CoreStability(false, jump.Check, coreTempK);
}

// A durable timer is stored by Dapr, not held in memory. Stop the app during the wait and
// the timer keeps running; the workflow continues when the app is back.
await context.CreateTimer(TimeSpan.FromSeconds(5));

// Continue-as-new restarts the workflow with new input and an empty history. A loop inside
// one run would grow the history with every check.
context.ContinueAsNew(new Jump(jump.JumpId, jump.Check + 1));
return null;
```

</details>

<details>
   <summary><b>Python</b></summary>

`python/demo4-monitor/engineering/workflow.py`:

```python,nocopy
core_temp_k = yield ctx.call_activity(read_core_temp_activity, input=check)

if core_temp_k <= 1000:
    return {"stable": True, "checks": check, "coreTempK": core_temp_k}

# The guard every monitor needs: give up after 10 checks.
if check == 10:
    return {"stable": False, "checks": check, "coreTempK": core_temp_k}

# A durable timer is stored by Dapr, not held in memory. Stop the app during the wait and
# the timer keeps running; the workflow continues when the app is back.
yield ctx.create_timer(timedelta(seconds=5))

# Continue-as-new restarts the workflow with new input and an empty history. A loop inside
# one run would grow the history with every check.
ctx.continue_as_new({"jumpId": jump["jumpId"], "check": check + 1})
```

</details>

<details>
   <summary><b>Java</b></summary>

`java/demo4-monitor/engineering/src/main/java/io/diagrid/university/workflow/engineering/CoreStabilityWorkflow.java`:

```java,nocopy
int coreTempK = ctx.callActivity("ReadCoreTempActivity", check, Integer.class).await();

if (coreTempK <= 1000) {
    ctx.complete(new CoreStability(true, check, coreTempK));
    return;
}

// The guard every monitor needs: give up after 10 checks.
if (check == 10) {
    ctx.complete(new CoreStability(false, check, coreTempK));
    return;
}

// A durable timer is stored by Dapr, not held in memory. Stop the app during the wait
// and the timer keeps running; the workflow continues when the app is back.
ctx.createTimer(Duration.ofSeconds(5)).await();

// Continue-as-new restarts the workflow with new input and an empty history. A loop
// inside one run would grow the history with every check.
ctx.continueAsNew(new Jump(jump.jumpId(), check + 1));
```

</details>

<details>
   <summary><b>TypeScript</b></summary>

`typescript/demo4-monitor/engineering/workflow.ts`:

```typescript,nocopy
const coreTempK: number = yield ctx.callActivity("ReadCoreTempActivity", check);

if (coreTempK <= 1000) {
  const stable: CoreStability = { stable: true, checks: check, coreTempK };
  return stable;
}

// The guard every monitor needs: give up after 10 checks.
if (check === 10) {
  const unstable: CoreStability = { stable: false, checks: check, coreTempK };
  return unstable;
}

// A durable timer is stored by Dapr, not held in memory. Stop the app during the wait and
// the timer keeps running; the workflow continues when the app is back. The argument is in seconds.
yield ctx.createTimer(5);

// Continue-as-new restarts the workflow with new input and an empty history. A loop inside
// one run would grow the history with every check.
ctx.continueAsNew({ jumpId: jump.jumpId, check: check + 1 } satisfies Jump);
```

</details>

Why continue-as-new? Every step a workflow takes is added to its history, and Dapr replays that history whenever the workflow continues. A monitor that loops inside one run would add to its history with every check, and the history would grow the longer the monitor runs. With continue-as-new, each check starts with an empty history, so the history stays small however long the monitor runs.

The timer is **durable** for the same reason the rest of the workflow is: Dapr stores it. It doesn't live in the app's memory, so a restart of the app during the 5 seconds doesn't lose it. A `sleep` or `Task.Delay` in the workflow code wouldn't give you that, and it isn't deterministic either.

## 5. Clean up

The workflow history stays in Redis after the app stops, and every demo in this track uses the same app ID, `engineering`. Use the **curl** window to purge the history of the finished jump while the app is still running:

```bash,run
dapr workflow purge --all -a engineering
```

## 6. Stop the applications

Use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

---

You ran a workflow that checks, waits on a durable timer and restarts itself with continue-as-new, until the core was stable.

## What's next?

In the next lab you'll make a workflow wait for a person: human in the loop, where a jump needs approval before it goes ahead.
