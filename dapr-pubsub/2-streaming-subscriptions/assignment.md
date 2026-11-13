# Streaming subscriptions

In this lab, you'll run a subscriber that has no port and no `Subscription` file, because it opens the connection to Dapr itself. This hands-on lab takes about 6 minutes to complete.

## Before you start

The terminals, and the applications running in them, stay as they are when you move between pages. Open the **Dev Dashboard** tab and look at which applications are running. If any are, for example `order-api`, `shipping` and `invoicing` from the previous lab, use the **Dapr CLI** window to stop them by pressing `Ctrl+C`.

If you used **Skip** or **Solve** on an earlier page, its apps run in the background, where `Ctrl+C` cannot reach them. This command stops every demo of this lab, however it was started. Run it in the **Dapr CLI** window (select that terminal in the dropdown that appears when you use the *Run* button):

```bash,run
for f in /root/ai-agent-tracks-instruqt/pubsub/*/*/dapr.yaml; do (cd "$(dirname "$f")" && dapr stop -f . >/dev/null 2>&1); done; echo "No demo of this lab is running now."
```

Then go back to the **Editor** tab.

## 1. A subscriber without a port

In the previous lab, Dapr called the subscriber: the sidecar read the subscription and then sent each message to an HTTP endpoint of the app. A **streaming** subscription turns that around. The app opens a stream to its own sidecar and pulls the messages in, so the app needs no HTTP server, no port, no `/dapr/subscribe` endpoint and no `Subscription` file.

> [!IMPORTANT]
> Streaming subscriptions are an alpha API in Dapr 1.19. The SDK calls and their names can still change in a later release.

Use the **Editor** tab and open the demo folder of your language: `dotnet/Demo2-Streaming`, `python/demo2-streaming` or `java/demo2-streaming`. It holds two apps, each with its own Dapr sidecar:

- `order-api` publishes an order to the topic `orders`. It listens on port 5101.
- `warehouse` subscribes to `orders`. It has no port at all.

Open `dapr.yaml` and compare the two apps. `order-api` has an `appPort`, and `warehouse` has none. The `resourcesPaths` list holds only the shared `pubsub` component, and there is no `Subscription` file in the demo.

Now open the code of the `warehouse` app for your language.

<details>
   <summary><b>.NET</b></summary>

Open `Program.cs` in the `dotnet/Demo2-Streaming/Warehouse` folder. The app is a generic host, not a web host. `client.SubscribeAsync("pubsub", "orders", options, HandleAsync, stoppingToken)` opens the stream, and `HandleAsync` runs for every message that arrives on it.

</details>

<details>
   <summary><b>Python</b></summary>

Open `app.py` in the `python/demo2-streaming/warehouse` folder. `client.subscribe_with_handler(pubsub_name="pubsub", topic="orders", handler_fn=receive_order)` opens the stream, and `receive_order` runs for every message that arrives on it.

</details>

<details>
   <summary><b>Java</b></summary>

Open `OrderStream.java` in the `java/demo2-streaming/warehouse/src/main/java/io/diagrid/university/pubsub/warehouse` folder. `client.subscribeToTopic("pubsub", "orders", TypeRef.BYTE_ARRAY)` opens the stream and returns a `Flux`, and `receiveOrder` runs for every message that arrives on it.

</details>

Each handler answers `Success` for every message, which tells Dapr the message is done. This demo does not show retry or drop.

## 2. Run the demo

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `pubsub` folder first. The terminal stays in whatever folder it was in when you move between pages, so this makes sure the commands below start from the right place:

```bash,run
cd /root/ai-agent-tracks-instruqt/pubsub
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo2-Streaming` for .NET, `demo2-streaming` for Python and Java. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo2-Streaming* folder:

```bash,run
cd dotnet/Demo2-Streaming
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo2-streaming* folder:

```bash,run
cd python/demo2-streaming
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo2-streaming* folder:

```bash,run
cd java/demo2-streaming
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Inspect the output of the **Dapr CLI** window. Wait until both applications are running before continuing. The Java applications can take a little longer to start.
>
> You can also check the application status in the **Dev Dashboard** tab: go to the **Applications** page and select `order-api` and `warehouse`.

The **Dapr CLI** window should show these lines when the sidecars have started. The port numbers can differ, and your applications' logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "order-api". HTTP Port: 3510. gRPC Port: 35935
ℹ️  Started Dapr with app id "warehouse". HTTP Port: 3511. gRPC Port: 39745
```

## 3. Ask the sidecar how the warehouse subscribed

The sidecar of the warehouse listens on port 3511. Use the **curl** window to ask for its subscriptions:

```bash,run
curl -s http://localhost:3511/v1.0/metadata | jq '.subscriptions'
```

Expected output:

```json,nocopy
[
  {
    "pubsubname": "pubsub",
    "topic": "orders",
    "rules": [
      {
        "path": "/"
      }
    ],
    "deadLetterTopic": "",
    "type": "STREAMING"
  }
]
```

The `type` is `STREAMING`, where the previous lab showed `DECLARATIVE` and `PROGRAMMATIC`. The subscription exists because the app opened a stream, and it disappears when the app stops. The `path` is only `/` because there is no endpoint to deliver to.

## 4. Send an order

Use the **curl** window to send an order to `order-api`, which publishes it to the topic `orders`:

```bash,run
curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
  -d '{"orderId":"o-2001","item":"coffee-beans","quantity":1,"priority":"standard"}'
```

Expected output:

```json,nocopy
{"orderId":"o-2001","topic":"orders"}
```

Now look at the **Dapr CLI** window. The warehouse logged the order:

```text,nocopy
== APP - warehouse == warehouse received order o-2001
```

Dapr pushed the message down the stream, and the warehouse answered `Success`. Nothing called the warehouse: it has no address to call.

## 5. An order the warehouse cannot read

Publish something that is not an order. Send it straight to the sidecar of `order-api`, on port 3510, as plain text:

```bash,run
curl -s -w '%{http_code}\n' -X POST http://localhost:3510/v1.0/publish/pubsub/orders \
  -H 'Content-Type: text/plain' -d 'not an order'
```

The sidecar answers `204`, which means it accepted the message. Look at the **Dapr CLI** window for the log line:

```text,nocopy
== APP - warehouse == warehouse dropped unreadable event
```

The text is not a JSON object with an `orderId`, so the warehouse logs it and still answers `Success`. An unreadable message will not be readable the next time either, so redelivering it would only repeat the failure. Because the warehouse acknowledged it, the stream stays open. Send the order from step 4 again with another `orderId` and you'll see it arrive.

## 6. Check your work and stop

Run the check below while the applications are still running: it asks them and reads their logs. When it passes, use the **Dapr CLI** window to stop the applications by pressing `Ctrl+C`.

<instruqt-task id="streaming"></instruqt-task>

---

A subscriber received orders over a stream it opened itself, with no port and no `Subscription` file.

## What's next?

In the next lab you'll look at what Dapr actually delivers: every message arrives wrapped in a CloudEvent. You'll publish one order normally and one as a raw payload, and see what the envelope adds and what raw drops.
