# Swap the broker

In this final lab, you'll run the apps of the previous lab against RabbitMQ instead of Redis, and change nothing but a YAML file. This hands-on lab takes about 7 minutes to complete. At the end of the lab, you can claim the Dapr University Holopin badge for this track.

## Before you start

The terminals, and the applications running in them, stay as they are when you move between labs. Open the **Dev Dashboard** tab and look at which applications are running. If any are, for example `order-api` and `shipping` from the previous lab, use the **Dapr CLI** window to stop them by pressing `Ctrl+C`. They use the same ports as the apps in this lab. Then go back to the **Editor** tab.

## 1. Start RabbitMQ

So far, every demo used the Redis that `dapr init` started. This time the broker is [RabbitMQ](https://www.rabbitmq.com/), which runs in a container.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **curl** window to start it. The terminal for `dapr run` is the **Dapr CLI** window, so this one stays free for the other commands:

```bash,run
docker rm -f rabbitmq >/dev/null 2>&1 || true
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:4.4.0-management
for _ in $(seq 1 60); do
  docker exec -u rabbitmq rabbitmq rabbitmq-diagnostics -q check_running >/dev/null 2>&1 &&
    docker exec -u rabbitmq rabbitmq rabbitmq-diagnostics -q check_port_connectivity >/dev/null 2>&1 && break
  sleep 1
done
```

The first line removes an existing container, so you can run this block again whenever you like. Port 5672 is what Dapr connects to, and port 15672 is the management UI and API. The block waits until the broker accepts connections on its ports, which can take up to a minute. Continue with the next section, we'll check RabbitMQ later.

## 2. A folder with no app code

Use the **Editor** tab and open the demo folder of your language: `dotnet/Demo6-SwapProvider`, `python/demo6-swap-provider` or `java/demo6-swap-provider`. It holds only configuration: a `dapr.yaml` and a `resources` folder with one file.

Open `dapr.yaml`. It starts the very same `order-api` and `shipping` apps as the previous lab, with `appDirPath` pointing at the folder of demo 5. Nothing is copied and nothing is changed. It also loads two resources folders:

- `./resources` has the `pubsub` component for RabbitMQ.
- The `resources` folder of demo 5 still holds the subscriptions and the resiliency policy.

The Redis component is not loaded this time. Open `pubsub.yaml` in the `resources` folder:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.rabbitmq
  version: v1
  metadata:
  - name: connectionString
    value: amqp://guest:guest@localhost:5672
  - name: durable
    value: "true"
  - name: deletedWhenUnused
    value: "false"
  - name: deliveryMode
    value: "2"
  - name: autoAck
    value: "false"
  - name: requeueInFailure
    value: "false"
```

The `name` is `pubsub`, the same as the Redis component. The apps publish to and subscribe through that name, so the name is the only thing they know about the broker. The `type` is what changed: `pubsub.rabbitmq` instead of `pubsub.redis`.

The `metadata` is specific to RabbitMQ. `durable`, `deletedWhenUnused` and `deliveryMode` keep exchanges, queues and messages when the broker restarts. `autoAck` is `false`, so Dapr acknowledges a message only after the app handled it. `requeueInFailure` is `false`, so RabbitMQ does not put a failed message back in the queue on its own. The retries still come from the resiliency policy, and the dead-lettering from the `deadLetterTopic` of the subscription, the same as with Redis. That is why RabbitMQ's own dead-letter feature stays off.

## 3. Run the demo

Use the **Dapr CLI** window to go to the `pubsub` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

```bash,run
cd /root/ai-agent-tracks-instruqt/pubsub
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo6-SwapProvider` for .NET, `demo6-swap-provider` for Python and Java. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo6-SwapProvider* folder:

```bash,run
cd dotnet/Demo6-SwapProvider
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo6-swap-provider* folder:

```bash,run
cd python/demo6-swap-provider
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo6-swap-provider* folder:

```bash,run
cd java/demo6-swap-provider
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
> Open the **Dev Dashboard** tab and check the application health on the **Applications** page: `order-api` and `shipping` are ready when the **Health** column shows a green dot. You can also inspect the output of the **Dapr CLI** window.

The **Dapr CLI** window should show these lines when the sidecars have started. The port numbers can differ, and your applications' logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "order-api". HTTP Port: 3510. gRPC Port: 35935
ℹ️  Started Dapr with app id "shipping". HTTP Port: 3511. gRPC Port: 39745
```

## 4. Send the same three orders

Use the **curl** window to send the three orders of the previous lab: a standard one, an express one and the poison one:

```bash,run
for o in \
  '{"orderId":"o-6001","item":"coffee-beans","quantity":1,"priority":"standard"}' \
  '{"orderId":"o-6002","item":"coffee-beans","quantity":1,"priority":"express"}' \
  '{"orderId":"o-6003","item":"poison","quantity":1,"priority":"standard"}'; do
  curl -s -X POST http://localhost:5101/orders -H 'Content-Type: application/json' -d "$o" | jq
done
```

Expected output:

```json,nocopy
{
  "orderId": "o-6001",
  "topic": "orders"
}
{
  "orderId": "o-6002",
  "topic": "orders"
}
{
  "orderId": "o-6003",
  "topic": "orders"
}
```

## 5. Read the log and look in the broker

Open the **Dev Dashboard** tab, go to the **Logs** page, select `shipping` in the application drop-down and type `order o-60` in the search bar. Wait a few seconds for the last line. The output is the same as in the previous lab:

```text,nocopy
== APP - shipping == shipping standard order o-6001
== APP - shipping == shipping express order o-6002
== APP - shipping == shipping rejected order o-6003
== APP - shipping == shipping rejected order o-6003
== APP - shipping == shipping rejected order o-6003
== APP - shipping == shipping rejected order o-6003
== APP - shipping == shipping dead-lettered order o-6003
```

Routing, 4 deliveries of the poison order and its arrival on `orders-dead` all work the same, because they are done by Dapr and by the subscription files, not by the broker. Now look at what Dapr created in RabbitMQ.

Open the **RabbitMQ** tab and log in with the user `guest` and the password `guest`. Under **Exchanges** you find `orders` and `orders-dead`, which are the topic names. Under **Queues and Streams** you find `shipping-orders` and `shipping-orders-dead`. Their names are `<app-id>-<topic>`: Dapr created one queue for each subscription of `shipping`. Then go back to the **Editor** tab.

You can also ask the management API from the **curl** window. These commands list the exchanges and the queues:

```bash,run
curl -s -u guest:guest http://localhost:15672/api/exchanges | jq -r '.[].name | select(startswith("orders"))' | sort
curl -s -u guest:guest http://localhost:15672/api/queues | jq -r '.[].name' | sort
```

Expected output:

```text,nocopy
orders
orders-dead
shipping-orders
shipping-orders-dead
```

## 6. Stop the applications

Use the **Dapr CLI** window to stop the applications by pressing `Ctrl+C`.

---

You ran the same applications and the same subscriptions against RabbitMQ instead of Redis. Their source files did not change, and neither did the subscription and resiliency files. What changed is the `pubsub` component file. That is what the pub/sub API gives you: your code publishes to a topic and subscribes to it by name, and which broker carries the messages is a decision for the platform.

Here is what you did in this track:

1. **Subscription types:** you subscribed `shipping` with a `Subscription` file and `invoicing` from code, and saw how the sidecar lists each one.
2. **Streaming subscriptions:** you received orders in an app that has no port and no endpoints, over a stream that the app opens to its sidecar.
3. **CloudEvents and raw payloads:** you received an order wrapped in a CloudEvent envelope, then published one as a raw payload, without the envelope.
4. **Bulk messages:** you published 25 orders in one call, received them in batches, and answered per entry with `SUCCESS` or `DROP`.
5. **Routing and dead letters:** you routed orders by their priority, and watched a failing order get retried 3 times and arrive on a dead-letter topic.
6. **Swap the broker:** you ran the same apps against a `pubsub` component that points at RabbitMQ, and saw that the component file is the only thing that differs.

## Collect your badge & provide feedback

Congratulations! 🎉 You've completed the Dapr University pub/sub learning track!

### Next steps

We have more opportunities for you to learn and share knowledge:

**Try another university track**
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Try these Dapr tools**
- [Dapr Dev Dashboard](https://docs.diagrid.io/dapr-open-source/dapr-dev-dashboard/), a free & OSS companion tool for local Dapr development.
- [Dapr Ops Dashboard](https://docs.diagrid.io/dapr-open-source/dapr-ops-dashboard/), a free SaaS solution that automates the operational management of Dapr on Kubernetes.

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#agents* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.

### Collect the badge

Collect the Dapr University badge for this track by following [this link to the Holopin platform](https://holopin.io/collect/cmwkvuq6x0003l4085i88jbl5). You'll need a GitHub account to claim the badge. Then come back to this page and click **Finish & Exit** below to finish the lab and provide feedback.

[![Dapr University Dapr Pub/Sub badge](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-pubsub/6-swap-the-broker/images/Diagrid-Dapr-Uni-badge-pubsub_x300.png?raw=true)](https://holopin.io/collect/cmwkvuq6x0003l4085i88jbl5)

<instruqt-completion text="You've completed Dapr Pub/Sub!"></instruqt-completion>
