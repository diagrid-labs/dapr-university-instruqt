# CloudEvents and raw payloads

In this lab, you'll publish one order normally and one as a raw payload, and see what the CloudEvent envelope adds and what raw publishing drops. This hands-on lab takes about 7 minutes to complete.

## Before you start

The terminals, and the applications running in them, stay as they are when you move between labs. Open the **Dev Dashboard** tab and look at which applications are running. If any are, for example `order-api` and `warehouse` from the previous lab, use the **Dapr CLI** window to stop them by pressing `Ctrl+C`. Then go back to the **Editor** tab.

## 1. Two subscriptions on one subscriber

Dapr does not hand a subscriber the bare message. Every message published through Dapr is wrapped in a **CloudEvent**: a standard JSON envelope, defined by the CloudEvents specification, that carries the message in its `data` field next to attributes such as the event `id`, the `source` and the `type`.

Use the **Editor** tab and open the demo folder of your language: `dotnet/Demo3-CloudEvents`, `python/demo3-cloud-events` or `java/demo3-cloud-events`. It holds two apps, each with its own Dapr sidecar:

- `order-api` listens on port 5101 and has two endpoints: `/orders` publishes to the topic `orders` and `/orders/raw` publishes to the topic `orders-raw`.
- `shipping` listens on port 5102 and subscribes to both topics.

Open the `resources` folder of the demo. It holds two `Subscription` files: `subscription-orders.yaml` sends the topic `orders` to the route `/orders`, and `subscription-orders-raw.yaml` sends the topic `orders-raw` to the route `/orders-raw`. Neither file has a `rawPayload` setting. Both have `scopes` beside `spec`, so only `shipping` loads them.

Now open the code of `order-api` and `shipping` for your language. The two publish endpoints differ by one thing.

<details>
   <summary><b>.NET</b></summary>

Open `Program.cs` in the `dotnet/Demo3-CloudEvents/OrderApi` folder. The `/orders/raw` endpoint publishes with the metadata `["rawPayload"] = "true"`, and `/orders` does not.

Open `Program.cs` in the `dotnet/Demo3-CloudEvents/Shipping` folder. The `/orders` endpoint logs the request body as it arrived and then reads it with the CloudEvents SDK. The `/orders-raw` endpoint only logs the body.

</details>

<details>
   <summary><b>Python</b></summary>

Open `app.py` in the `python/demo3-cloud-events/order-api` folder. The `/orders/raw` endpoint publishes with the metadata `{"rawPayload": "true"}`, and `/orders` does not.

Open `app.py` in the `python/demo3-cloud-events/shipping` folder. The `/orders` endpoint logs the request body as it arrived and then reads it with the CloudEvents SDK. The `/orders-raw` endpoint only logs the body.

</details>

<details>
   <summary><b>Java</b></summary>

Open `OrderController.java` in the `java/demo3-cloud-events/order-api/src/main/java/io/diagrid/university/pubsub/orderapi` folder. The `/orders/raw` endpoint publishes with the metadata `Map.of("rawPayload", "true")`, and `/orders` does not.

Open `OrderController.java` in the `java/demo3-cloud-events/shipping/src/main/java/io/diagrid/university/pubsub/shipping` folder. The `/orders` endpoint logs the request body as it arrived and then reads it with the CloudEvents SDK. The `/orders-raw` endpoint only logs the body.

</details>

The `shipping` app has no Dapr code at all. It logs exactly the bytes Dapr sends, which makes it a good place to look at the envelope.

## 2. Run the demo

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `pubsub` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

```bash,run
cd /root/ai-agent-tracks-instruqt/pubsub
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo3-CloudEvents` for .NET, `demo3-cloud-events` for Python and Java. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo3-CloudEvents* folder:

```bash,run
cd dotnet/Demo3-CloudEvents
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo3-cloud-events* folder:

```bash,run
cd python/demo3-cloud-events
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo3-cloud-events* folder:

```bash,run
cd java/demo3-cloud-events
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Wait until both applications are running before continuing. The Java applications can take a little longer to start.
>
> Open the **Dev Dashboard** tab and check the application health on the **Applications** page: select `order-api` and `shipping`. You can also inspect the output of the **Dapr CLI** window.

The **Dapr CLI** window should show these lines when the sidecars have started. The port numbers can differ, and your applications' logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "order-api". HTTP Port: 3510. gRPC Port: 35935
ℹ️  Started Dapr with app id "shipping". HTTP Port: 3511. gRPC Port: 39745
```

## 3. Publish an order normally

Use the **curl** window to send an order to `order-api`. It publishes the order to the topic `orders` without any extra metadata:

```bash,run
curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
  -d '{"orderId":"o-3001","item":"coffee-beans","quantity":2,"priority":"standard"}'
```

Expected output:

```json,nocopy
{"orderId":"o-3001","topic":"orders"}
```

`shipping` logs the request body exactly as Dapr sent it. Open the **Dev Dashboard** tab, go to the **Logs** page, select `shipping` in the application drop-down and type `o-3001` in the search bar. The log line is on one line. It is wrapped here so you can read it:

```text,nocopy
== APP - shipping == shipping received with envelope:
{"data":{"item":"coffee-beans","orderId":"o-3001","priority":"standard","quantity":2},
"datacontenttype":"application/json",
"id":"6ce4e90a-c8aa-49bd-83ad-2c9f121cda9e",
"pubsubname":"pubsub",
"source":"order-api",
"specversion":"1.0",
"time":"2026-11-11T23:17:46+01:00",
"topic":"orders",
"traceid":"00-eff559eb42be353e9621e35a4ebd2a54-00779deeb981362a-00",
"traceparent":"00-eff559eb42be353e9621e35a4ebd2a54-00779deeb981362a-00",
"tracestate":"",
"type":"com.dapr.event.sent"}
```

Your `id`, `time` and trace values are different, and the exact fields and their order vary a little between SDKs. The order you sent is in `data`. Everything around it is the envelope:

- `id`, `source`, `type` and `specversion` identify the event. Dapr fills them in: the `source` is the app ID of the publisher.
- `traceparent` and `traceid` carry the trace context, so a trace can follow the message from the publisher to the subscriber.
- `pubsubname` and `topic` say where the message travelled.

Right after it, `shipping` reads the same envelope with the open CloudEvents SDK and logs a few of its attributes. Search for `parsed CloudEvent` to find that line:

```text,nocopy
== APP - shipping == shipping parsed CloudEvent id=6ce4e90a-c8aa-49bd-83ad-2c9f121cda9e type=com.dapr.event.sent source=order-api
```

This works because Dapr delivers a standard CloudEvent, so a subscriber needs no Dapr library to read it.

## 4. Publish an order as a raw payload

Now send an order to the other endpoint. `order-api` publishes it to the topic `orders-raw` with the metadata `rawPayload` set to `true`:

```bash,run
curl -s -X POST http://localhost:5101/orders/raw -H 'Content-Type: application/json' \
  -d '{"orderId":"o-3002","item":"coffee-beans","quantity":3,"priority":"express"}'
```

Expected output:

```json,nocopy
{"orderId":"o-3002","topic":"orders-raw"}
```

On the **Logs** page, search the `shipping` log for `o-3002`:

```text,nocopy
== APP - shipping == shipping received raw: {"orderId":"o-3002","item":"coffee-beans","quantity":3,"priority":"express"}
```

`shipping` received the bare order, exactly as you posted it. There is no envelope, so there is no CloudEvent for the SDK to read, and `shipping` does not try to: this endpoint only logs the body.

## 5. What raw publishing drops

Compare the two log lines. Raw publishing drops everything the envelope carried: the event `id`, `source`, `type` and `specversion`, and the trace context. In return, the message on the broker is only your data. That is worth it when the other side is not a Dapr app, for example a consumer that expects plain JSON.

The `rawPayload` metadata is set by the **publisher** only. Look at `subscription-orders-raw.yaml` again: the subscription does not carry it. A subscription with `rawPayload: "true"` does the opposite job. It is meant for consuming raw messages from non-Dapr producers, and Dapr then wraps each message it receives in a CloudEvent. The bytes go in `data_base64` and the `datacontenttype` is `application/octet-stream`. If you added `rawPayload: "true"` to the `orders-raw` subscription, `shipping` would receive this instead of the bare order (shortened here):

```text,nocopy
{"data_base64":"eyJvcmRlcklkIjoi...","datacontenttype":"application/octet-stream","id":"a669a99e-24ea-45cc-b899-6b135c894d94","pubsubname":"pubsub","source":"Dapr","specversion":"1.0","topic":"orders-raw","type":"com.dapr.event.sent", ...}
```

You do not need to try this. Remember it as: the publisher chooses raw to leave the envelope off, and the subscriber chooses raw to put one on.

## 6. Stop the applications

Use the **Dapr CLI** window to stop the applications by pressing `Ctrl+C`.

---

A subscriber received one order wrapped in a CloudEvent and one as a raw payload, and you saw what raw publishing leaves out.

## What's next?

In the next lab you'll publish many orders in one call and receive them in batches, so a subscriber handles several messages per request.
