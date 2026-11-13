# Subscription types

In this lab, you'll run two apps that subscribe to the same topic in two different ways and send one order that reaches both of them. This hands-on lab takes about 8 minutes to complete.

## 1. Why pub/sub?

An order system has a publisher, the app that announces "a new order came in", and subscribers, the apps that react to it, such as shipping and invoicing. The publisher sends the message to a *topic*, and a *broker* delivers a copy to every app that subscribes to that topic. The publisher does not know who is listening, so you can add a subscriber without changing it.

With Dapr, no app talks to the broker. The publisher sends the message to its Dapr sidecar and the sidecar hands it to the broker. Which broker that is lives in a Dapr component named `pubsub`. In this lab the component points at Redis, and in the last lab you'll swap it for RabbitMQ without touching the apps.

The question for the next minutes is how a subscriber tells Dapr which topic it wants. There are three ways: declarative, programmatic and streaming. This lab covers the first two, and the next one covers streaming.

## 2. Two subscribers, two subscription types

Use the **Editor** tab and open the demo folder of your language: `dotnet/Demo1-Subscriptions`, `python/demo1-subscriptions` or `java/demo1-subscriptions`. It holds three apps, each with its own Dapr sidecar:

- `order-api` publishes an order to the topic `orders`. It listens on port 5101.
- `shipping` subscribes to `orders` and listens on port 5102.
- `invoicing` subscribes to `orders` as well and listens on port 5103.

The `shipping` subscription is **declarative**: it is a YAML file, outside the app. Open `subscription-shipping.yaml` in the `resources` folder of the demo:

```yaml,nocopy
apiVersion: dapr.io/v2alpha1
kind: Subscription
metadata:
  name: shipping-orders
spec:
  pubsubname: pubsub
  topic: orders
  routes:
    default: /orders
scopes:
  - shipping
```

It says: deliver every message on the topic `orders` of the component `pubsub` to the route `/orders`. The `scopes` list names the app that loads this subscription, which is `shipping`. Notice that `scopes` sits beside `spec`, not inside it. Inside `spec` it is ignored, and then every sidecar loads the subscription, including the publisher's.

The `invoicing` subscription is **programmatic**: it lives in the code of the app. Open the file for your language.

<details>
   <summary><b>.NET</b></summary>

Open `Program.cs` in the `dotnet/Demo1-Subscriptions/Invoicing` folder. `MapSubscribeHandler()` serves the `/dapr/subscribe` endpoint, and `.WithTopic("pubsub", "orders")` on the `/orders` route is the subscription.

</details>

<details>
   <summary><b>Python</b></summary>

Open `app.py` in the `python/demo1-subscriptions/invoicing` folder. `DaprApp` serves the `/dapr/subscribe` endpoint, and `@dapr_app.subscribe(pubsub="pubsub", topic="orders", route="/orders")` is the subscription.

</details>

<details>
   <summary><b>Java</b></summary>

Open `OrderController.java` in the `java/demo1-subscriptions/invoicing/src/main/java/io/diagrid/university/pubsub/invoicing` folder. The Dapr SDK serves the `/dapr/subscribe` endpoint, and `@Topic(name = "orders", pubsubName = "pubsub")` on the `/orders` route is the subscription.

</details>

When the sidecar of `invoicing` starts, it asks the app on `/dapr/subscribe` which topics it wants. The sidecar of `shipping` reads the YAML file instead, and the `shipping` app has no Dapr code at all. It reads each message with the open CloudEvents SDK, because Dapr delivers every message as a standard CloudEvent. You'll look at that envelope on a later page.

## 3. Run the demo

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `pubsub` folder first. The terminal stays in whatever folder it was in when you move between pages, so this makes sure the commands below start from the right place:

```bash,run
cd /root/ai-agent-tracks-instruqt/pubsub
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo1-Subscriptions` for .NET, `demo1-subscriptions` for Python and Java. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo1-Subscriptions* folder:

```bash,run
cd dotnet/Demo1-Subscriptions
```

Run the three applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo1-subscriptions* folder:

```bash,run
cd python/demo1-subscriptions
```

Run the three applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo1-subscriptions* folder:

```bash,run
cd java/demo1-subscriptions
```

Run the three applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Inspect the output of the **Dapr CLI** window. Wait until all three applications are running before continuing. The Java applications can take a little longer to start.
>
> You can also check the application status in the **Dev Dashboard** tab: go to the **Applications** page and select `order-api`, `shipping` and `invoicing`.

The **Dapr CLI** window should show these lines when the sidecars have started. The port numbers can differ, and your applications' logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "order-api". HTTP Port: 3510. gRPC Port: 35935
ℹ️  Started Dapr with app id "shipping". HTTP Port: 3511. gRPC Port: 39745
ℹ️  Started Dapr with app id "invoicing". HTTP Port: 3512. gRPC Port: 41023
```

## 4. Send one order to both

Use the **curl** window to send an order to `order-api`, which publishes it to the topic `orders`:

```bash,run
curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' \
  -d '{"orderId":"o-1001","item":"coffee-beans","quantity":2,"priority":"standard"}'
```

Expected output:

```json,nocopy
{"orderId":"o-1001","topic":"orders"}
```

Now look at the **Dapr CLI** window. Both subscribers logged the order, and the order of the two lines can differ. The lines below show only the message: in the real output, each language adds its own logger prefix after `== APP - <app> ==`, for example `INFO:shipping:` in Python and a timestamped Spring log header in Java.

```text,nocopy
== APP - shipping == shipping received order o-1001
== APP - invoicing == invoicing received order o-1001
```

You published one message and two apps received it. A topic delivers a copy to every subscriber, whichever way each one subscribed. `order-api` never knew that `shipping` and `invoicing` exist.

## 5. Ask the sidecars how they subscribed

Every sidecar lists its subscriptions on the metadata endpoint, together with how each one was registered. Use the **curl** window to ask the sidecar of `shipping`, on port 3511:

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
        "path": "/orders"
      }
    ],
    "deadLetterTopic": "",
    "type": "DECLARATIVE"
  }
]
```

Now ask the sidecar of `invoicing`, on port 3512:

```bash,run
curl -s http://localhost:3512/v1.0/metadata | jq '.subscriptions'
```

Expected output:

```json,nocopy
[
  {
    "pubsubname": "pubsub",
    "topic": "orders",
    "rules": [
      {
        "path": "/orders"
      }
    ],
    "deadLetterTopic": "",
    "type": "PROGRAMMATIC"
  }
]
```

The two subscriptions look the same, except for the `type`. `DECLARATIVE` came from the YAML file and `PROGRAMMATIC` came from the app's `/dapr/subscribe` answer. Declarative keeps the wiring out of the code, so you can change a topic or a route without rebuilding the app. Programmatic keeps the wiring next to the handler it belongs to.

The publisher has no subscription at all, because the `scopes` of the YAML file keep it from loading one:

```bash,run
curl -s http://localhost:3510/v1.0/metadata | jq '.subscriptions'
```

Expected output:

```text,nocopy
null
```

## 6. Shipping reads a CloudEvent

The `shipping` app uses the CloudEvents SDK, not a Dapr SDK, so it can only handle a real CloudEvent. Post something that is not one straight to the app, bypassing Dapr:

```bash,run
curl -s -X POST http://localhost:5102/orders -H 'Content-Type: application/json' -d 'not json'
```

The app answers with the status `DROP`. Look at the **Dapr CLI** window for the log line:

```text,nocopy
== APP - shipping == shipping dropped unreadable event
```

`DROP` tells Dapr to throw the message away. The app does not answer with an error status, because Dapr would then deliver the same message again, and a message that cannot be read now will not be readable next time either.

## 7. Check your work and stop

Run the check below while the applications are still running: it asks them and reads their logs. When it passes, use the **Dapr CLI** window to stop the applications by pressing `Ctrl+C`.

<instruqt-task id="subscription_types"></instruqt-task>

---

One order reached two apps, one subscribed declaratively and one programmatically.

## What's next?

In the next lab you'll look at the third subscription type. A streaming subscription needs no `Subscription` file and no HTTP endpoint at all: the app opens a connection to its own sidecar and pulls the messages in.
