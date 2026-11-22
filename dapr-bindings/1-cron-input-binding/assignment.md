# Cron input binding

In this lab, you'll let Dapr call an app on a schedule through a cron input binding, and change that schedule without touching the code. This hands-on lab takes about 6 minutes to complete.

## 1. What is a binding?

Most apps talk to something outside themselves: a schedule, a database, a queue, a mail server. A Dapr *binding* connects an app to such a system through its Dapr sidecar. The app never loads a client library for that system. Which system it is, and how to reach it, lives in a Dapr component, a YAML file.

A binding works in one of two directions:

- An **input binding** lets the outside system call your app. Something happens out there, such as a timer firing or a message arriving, and the sidecar sends an HTTP request to your app.
- An **output binding** lets your app call the outside system. The app sends a request to its sidecar, such as "run this SQL", and the sidecar passes it on.

The demos in this track tell one story. A starship's **engineering** console logs warp-core readings on a schedule, stores them in a PostgreSQL database and, in the last lab, pings a **subspace beacon** to open a communications channel. In this lab you'll build the first part: a cron input binding that makes the console take a reading every 10 seconds.

## 2. The component and the handler

Use the **Editor** tab and open the demo folder of your language: `dotnet/Demo1-CronTrigger`, `python/demo1-cron-trigger` or `java/demo1-cron-trigger`. It holds one app, `engineering`, which listens on port 5201.

Open `warp-core-scan.yaml` in the `resources` folder of the demo:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: warp-core-scan
spec:
  type: bindings.cron
  version: v1
  metadata:
    - name: schedule
      value: "@every 10s"
    - name: direction
      value: "input"
```

The component is a binding of type `bindings.cron` with a schedule of every 10 seconds. `direction: input` says that Dapr calls the app, not the other way around. On every tick the sidecar sends a `POST` request to the app, and the route of that request is the name of the component: `/warp-core-scan`.

Now open the handler for your language.

<details>
   <summary><b>.NET</b></summary>

Open `Program.cs` in the `dotnet/Demo1-CronTrigger/Engineering` folder. `app.MapPost("/warp-core-scan", ...)` is a plain ASP.NET Core endpoint that creates a reading and logs it.

</details>

<details>
   <summary><b>Python</b></summary>

Open `app.py` in the `python/demo1-cron-trigger/engineering` folder. `@app.post("/warp-core-scan")` is a plain FastAPI endpoint that creates a reading and logs it.

</details>

<details>
   <summary><b>Java</b></summary>

Open `ScanController.java` in the `java/demo1-cron-trigger/engineering/src/main/java/io/diagrid/university/bindings/engineering` folder. `@PostMapping("/warp-core-scan")` is a plain Spring endpoint that creates a reading and logs it.

</details>

The app has no Dapr code at all: no Dapr package, no attribute, no decorator, no timer. It serves an HTTP endpoint whose path matches the component name, and answers `200` to tell Dapr the tick was handled.

## 3. Run the demo

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `bindings` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

```bash,run
cd /root/university-labs/bindings
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo1-CronTrigger` for .NET, `demo1-cron-trigger` for Python and Java. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo1-CronTrigger* folder:

```bash,run
cd dotnet/Demo1-CronTrigger
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo1-cron-trigger* folder:

```bash,run
cd python/demo1-cron-trigger
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo1-cron-trigger* folder:

```bash,run
cd java/demo1-cron-trigger
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

The **Dapr CLI** window should show this line when the sidecar has started. The gRPC port can differ, and your application's logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "engineering". HTTP Port: 3520. gRPC Port: 35935
```

## 4. Watch the scans

Ten seconds after the app starts, and then every ten seconds, `engineering` logs a warp-core scan. `dapr run -f .` writes the log of the app and its sidecar to a file in the `.dapr/logs` folder of the app, and the **Dev Dashboard** reads that file for you:

1. Open the **Dev Dashboard** tab and go to the **Logs** page.
2. Select `engineering` in the application drop-down.
3. Type `warp-core scan` in the search bar.

The lines below show only the message. In the real log, Python and Java put their own logger prefix in front of it, and .NET writes an `info: Program[0]` line followed by the message on a line of its own. The readings and stardates in your log will differ:

```text,nocopy
== APP - engineering == engineering warp-core scan wc-0001 stardate=85763.0 coreTempK=859 plasmaFlow=0.76
== APP - engineering == engineering warp-core scan wc-0002 stardate=85763.0 coreTempK=912 plasmaFlow=0.90
```

The app has no timer, yet it logs a scan every ten seconds. The sidecar keeps the schedule and calls the app.

Ask the sidecar which components it loaded. Use the **curl** window:

```bash,run
curl -s http://localhost:3520/v1.0/metadata | jq '.components'
```

Expected output:

```json,nocopy
[
  {
    "name": "warp-core-scan",
    "type": "bindings.cron",
    "version": "v1",
    "capabilities": [
      "INPUT_BINDING"
    ]
  }
]
```

The sidecar loaded one component, the cron binding, and lists it as an `INPUT_BINDING`. The `dapr.yaml` of demo 1 loads only the demo's own `resources` folder, so there is no database yet.

You can also find the component in the **Dev Dashboard** tab. Go to the **Components** page: `warp-core-scan` is at the bottom of the component list, with the type `bindings.cron`.

> [!NOTE]
> A cron tick is fire and forget. If the handler answers with an error, Dapr does not retry that tick and does not move the schedule: the next tick arrives on time. The sidecar logs nothing about it at its default log level, so a failure only shows in the app's own log. That is why the handlers in the next labs log their own errors.

## 5. Change the schedule

The schedule lives in YAML, so you can change it without rebuilding the app.

Use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

Use the **Editor** tab to open `warp-core-scan.yaml` in the `resources` folder of your demo again, and change `@every 10s` to `@every 3s`. The file should read like this afterwards:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: warp-core-scan
spec:
  type: bindings.cron
  version: v1
  metadata:
    - name: schedule
      value: "@every 3s"
    - name: direction
      value: "input"
```

The Editor saves the file automatically. Use the **Dapr CLI** window to start the application again, from the same demo folder:

```bash,run
dapr run -f .
```

On the **Logs** page of the **Dev Dashboard** tab, select `engineering` again and search for `warp-core scan`. The counter starts again at `wc-0001`, because it belongs to the app process, and the scans now arrive every three seconds. The code did not change; only the component did.

> [!NOTE]
> The schedule also accepts cron expressions, such as `0 */5 * * * *` for every five minutes, and shortcuts such as `@hourly`.

## 6. Stop the applications

Use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

---

A cron input binding called your app on a schedule. The app only served an HTTP endpoint named after the component, and the schedule changed with an edit to YAML.

## What's next?

In the next lab you'll use the other direction. The app sends SQL to a PostgreSQL output binding to store every reading, query them, and purge old ones.
