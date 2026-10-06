Every handler in this track has so far returned a success status. Real subscribers don't always get to: a malformed payload, a validation failure, a schema the code doesn't know about. If Dapr just kept redelivering such a message, it would block the topic forever — a *poison message*. A **dead letter topic** is where that message goes instead, so the queue keeps moving and a human (or another service) can look at it later. This challenge takes about 6 minutes to complete.

## 1. Two subscriptions, one dead letter topic

Open `Demo7-Resiliency/Resources/subscription.yaml` in the *Editor* tab:

```yaml,nocopy
apiVersion: dapr.io/v2alpha1
kind: Subscription
metadata:
  name: receiver-sub
spec:
  pubsubname: demo7-pubsub
  topic: incoming-messages
  deadLetterTopic: deadletter-messages
  routes:
    default: /messagehandler
scopes:
- receiver
```

One new line does the work: **`deadLetterTopic: deadletter-messages`**. When `receiver` gives up on a message, Dapr republishes it to the `deadletter-messages` topic on the same component.

A dead letter topic is an ordinary topic, which means something has to subscribe to it. Open `Demo7-Resiliency/Resources/subscription-deadletter.yaml`:

```yaml,nocopy
apiVersion: dapr.io/v2alpha1
kind: Subscription
metadata:
  name: deadletter-sub
spec:
  pubsubname: demo7-pubsub
  topic: deadletter-messages
  routes:
    default: /messagehandler
scopes:
- deadletter
```

That's scoped to the third app in this demo, `DeadLetterService`, whose handler just logs what it got:

```csharp,nocopy
app.MapPost("/messagehandler", (
    TinyMessage message) =>
{
    Console.WriteLine($"Received deadletter message {message.Id}.");

    return Results.Accepted();
});
```

> [!IMPORTANT]
> Configuring `deadLetterTopic` without subscribing to it is a real trap. Dapr will happily publish rejected messages to a topic nobody reads, and they'll sit there unnoticed.

## 2. Retried, or dead-lettered?

Whether a rejection is retried or dead-lettered is decided by a **resiliency policy**. Open `Demo7-Resiliency/Resources/resiliency.yaml`:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Resiliency
metadata:
  name: resiliency-policy1
spec:
  policies:
    retries:
      pubsubRetry5xx:
        policy: constant
        duration: 1s
        maxRetries: 30
        matching:
          httpStatusCodes: 500-599
      pubsubRetryExp:
        policy: exponential
        maxInterval: 60s
        maxRetries: -1
  targets:
    components:
      demo7-pubsub:
        inbound:
          retry: pubsubRetry5xx
        outbound:
          retry: pubsubRetryExp
```

- **`inbound`** applies to messages Dapr delivers *to* the app. The `pubsubRetry5xx` policy retries every second, up to 30 times — but the `matching.httpStatusCodes: 500-599` clause means it only retries **5xx** responses. Anything else the app returns is not retried, so it goes straight to the dead letter topic.
- **`outbound`** applies to Dapr's calls *to the broker*. `pubsubRetryExp` retries publishing forever with exponential backoff, so a temporarily unreachable broker doesn't lose a publish.

That distinction is the point of this challenge:

| Receiver returns | Retried? | Ends up |
|---|---|---|
| `202 Accepted` | n/a | Acknowledged, done |
| `503 Service Unavailable` | Yes, 30 times, 1s apart | Dead letter topic if it never succeeds |
| `429 Too Many Requests` | No — outside `500-599` | Dead letter topic immediately |

## 3. Run the happy path first

Open `Demo7-Resiliency/ReceiverService/Program.cs`. As it stands, the handler accepts everything, and the two interesting responses are commented out:

```csharp,nocopy
app.MapPost("/messagehandler", (
    TinyMessage message) =>
{
    Console.WriteLine($"Received message {message.Id}.");

    return Results.Accepted();
    //return Results.Problem("Service Unavailable", statusCode: (int)HttpStatusCode.ServiceUnavailable); //503 This will retry
    //return Results.Problem("Too many requests", statusCode: (int)HttpStatusCode.TooManyRequests); //429 This will not retry
});
```

Start all three applications from the **Dapr CLI** window:

```bash,run
cd Demo7-Resiliency
dapr run -f .
```

> [!IMPORTANT]
> Wait until you see `Started Dapr with app id "deadletter".` before continuing — the Dapr CLI prints one such line per app, and `deadletter` is the last one to start.

Publish a message from the **curl** window:

```curl,run
curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"77777777-0000-0000-0000-000000000001","timeStamp":"2026-01-01T12:00:00Z"}'
```

Expected application log statements:

```text,nocopy
== APP - sender == Sent message 77777777-0000-0000-0000-000000000001.
== APP - receiver == Received message 77777777-0000-0000-0000-000000000001.
```

The `deadletter` app logged nothing, because nothing was rejected.

Stop the applications by pressing `Ctrl+C` in the **Dapr CLI** window.

## 4. Make the receiver reject the message

Now make the handler return `429 Too Many Requests` — a status the resiliency policy does *not* retry.

In the *Editor* tab, open `Demo7-Resiliency/ReceiverService/Program.cs` and change the handler so it looks like this: comment out the `Results.Accepted()` line, and uncomment the `429` line.

```csharp,copy
app.MapPost("/messagehandler", (
    TinyMessage message) =>
{
    Console.WriteLine($"Received message {message.Id}.");

    //return Results.Accepted();
    //return Results.Problem("Service Unavailable", statusCode: (int)HttpStatusCode.ServiceUnavailable); //503 This will retry
    return Results.Problem("Too many requests", statusCode: (int)HttpStatusCode.TooManyRequests); //429 This will not retry
});
```

The file should auto-save.

> [!IMPORTANT]
> Click the *Check* button to verify the code change before continuing.

## 5. Follow the message to the dead letter topic

Start the applications again from the **Dapr CLI** window:

```bash,run
dapr run -f .
```

Publish another message from the **curl** window:

```curl,run
curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"77777777-0000-0000-0000-000000000002","timeStamp":"2026-01-01T12:00:00Z"}'
```

Expected application log statements:

```text,nocopy
== APP - sender == Sent message 77777777-0000-0000-0000-000000000002.
== APP - receiver == Received message 77777777-0000-0000-0000-000000000002.
== APP - deadletter == Received deadletter message 77777777-0000-0000-0000-000000000002.
```

The `receiver` app saw the message and rejected it with a 429. Because 429 is outside the `500-599` range the retry policy matches, Dapr didn't retry — it republished the message to `deadletter-messages`, where `deadletter` picked it up on its own subscription.

> [!NOTE]
> You'll also see warning-level lines from the `receiver` sidecar, reading something like `retriable error returned from app while processing pub/sub event ..., status code returned: 429`. Don't let the word *retriable* mislead you: Dapr classifies the response as one it *could* retry, but the resiliency policy's `matching.httpStatusCodes` clause is what decides whether it actually does — and 429 isn't in `500-599`. A dead-lettered message is a handled failure, not a silent one, and these are the lines you'd alert on in production.

Try the other response if you have time: swap the active line for the `503 Service Unavailable` one and publish again. This time the retry policy *does* match, so the **Dapr CLI** window fills with one redelivery per second for 30 seconds before the message is finally dead-lettered.

Stop the applications by pressing `Ctrl+C` in the **Dapr CLI** window, then go back up one folder:

```bash,run
cd ..
```

## 6. Dead lettering in practice

- **A dead letter topic is a queue of work, not a bin.** Something must consume it — a service that logs and alerts, writes to a store for inspection, or replays messages onto the original topic after a fix.
- **Match your retry policy to your failure modes.** Transient failures (a database blip, a rate limit downstream) deserve retries; permanent ones (a payload that will never validate) should be dead-lettered on the first attempt. The `matching.httpStatusCodes` clause is how you draw that line.
- **The dead-lettered message keeps its CloudEvent envelope,** so the consumer can still see the original `source`, `type` and `traceid` — which is usually how you find out *why* it failed.

For more detail, read [Dead Letter Topics](https://docs.dapr.io/developing-applications/building-blocks/pubsub/pubsub-deadletter/) and [Resiliency policies](https://docs.dapr.io/operations/resiliency/policies/) in the Dapr docs.

## Summary

Congratulations! 🎉 You've completed the *Dapr Pub/Sub messaging in depth* track. You've used:

- **Declarative, programmatic, and streaming subscriptions**, and know which one to reach for.
- The **CloudEvents envelope** Dapr wraps around every message, and how to override its attributes.
- **Bulk publishing** and **bulk subscriptions**, and why they're independent choices.
- **Content-based routing** with match expressions and priorities.
- **Dead letter topics** and **resiliency policies** to keep a poison message from blocking a topic.

The repository you worked in has three more demos that this track didn't cover — the outbox pattern (`Demo8-Outbox`) and broker switching to RabbitMQ and Azure Service Bus (`Demo1-Declarative`). All of it is on GitHub at [diagrid-labs/dapr-pub-sub-deep-dive](https://github.com/diagrid-labs/dapr-pub-sub-deep-dive) if you want to keep going locally.

Please take a moment to rate this training and provide feedback in the next step so we can keep improving it 🚀.

## Next steps

**Try another university track**
- [Dapr 101: State Management, Service Invocation, and Pub/Sub APIs](https://www.diagrid.io/university/dapr-101)
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Read more**
- [Understanding Dapr Pub/Sub Subscription Types](https://www.diagrid.io/blog/understanding-dapr-pub-sub-subscription-types-declarative-programmatic-streaming)
- The [Pub/Sub API reference](https://docs.dapr.io/reference/api/pubsub_api/) in the Dapr docs.

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#pubsub*, *#workflow* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.
