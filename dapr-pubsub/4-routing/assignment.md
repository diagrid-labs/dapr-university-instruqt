A topic usually carries more than one kind of message, and a subscriber usually wants a different handler for each kind. The naive fix is one topic per message type, which multiplies your topics and couples publishers to consumers. Dapr's answer is **content-based routing**: one topic, and a subscription that dispatches to different endpoints based on what's inside each message. This challenge takes about 5 minutes to complete.

## 1. A slightly bigger message

The message in this demo has two extra fields to route on. Open `Demo6-Routing/SenderService/Program.cs`:

```csharp,nocopy
record TinyMessage(Guid Id, DateTime TimeStamp, string Type, int Amount = 0);
```

The publishing code is unchanged — routing is a subscriber-side concern, and the sender has no idea which handler its message will reach:

```csharp,nocopy
await daprClient.PublishEventAsync(
    PubSubComponentName,
    TopicName,
    message);
Console.WriteLine($"Sent message {message.Id} with type {message.Type}.");
```

## 2. Routing rules in code

Open `Demo6-Routing/ReceiverService1/Program.cs`. This receiver subscribes programmatically, and its two `[Topic]` attributes carry a **match expression** and a **priority**:

```csharp,nocopy
const string ROUTE_TYPE1 = "event.data.type == \"dapr.demo.type1\"";
const string ROUTE_TYPE1_LARGEAMOUNT = "event.data.type == \"dapr.demo.type1\" && event.data.amount > 10";
const int PRIORITY100 = 100; // Higher priority
const int PRIORITY200 = 200; // Lower priority

app.MapPost("/handletype1",
    [Topic(PUBSUB_NAME, TOPIC_NAME, ROUTE_TYPE1, PRIORITY200)] (
    TinyMessage message) =>
{
    Console.WriteLine($"Type1 - Received message {message.Id}: {message.Type}.");

    return Results.Accepted();
});

app.MapPost("/handlelargeamount",
    [Topic(PUBSUB_NAME, TOPIC_NAME, ROUTE_TYPE1_LARGEAMOUNT, PRIORITY100)] (
    TinyMessage message) =>
{
    Console.WriteLine($"Large amount - Received message {message.Id}: {message.Type}.");

    return Results.Accepted();
});
```

Both rules match a message with `type == "dapr.demo.type1"`, but only one handler gets it. The **priority** breaks the tie: rules are evaluated in ascending priority order, so `PRIORITY100` is checked before `PRIORITY200`, and the **first matching rule wins**. A `dapr.demo.type1` message with `amount > 10` therefore goes to `/handlelargeamount`; the same message with a small amount falls through to `/handletype1`.

> [!IMPORTANT]
> Order the specific rules before the general ones. If `ROUTE_TYPE1` had the lower priority number, it would match everything of that type first and `/handlelargeamount` would never be reached.

The expressions are [Common Expression Language](https://github.com/google/cel-spec) (CEL) and they're evaluated against the **CloudEvent**, which is why `event.data.type` has that shape:

- `event.data.type` — the `type` field of *your payload*, inside the envelope's `data`.
- `event.type` — the CloudEvent's own `type` attribute, the one you overrode in challenge 2.

Those are two different things, and mixing them up is the usual reason a rule never matches.

## 3. Routing rules in YAML

The same routing can be declared outside the application. Open `Demo6-Routing/Resources/subscription.yaml`:

```yaml,nocopy
apiVersion: dapr.io/v2alpha1
kind: Subscription
metadata:
  name: receiver-sub
spec:
  pubsubname: demo6-pubsub
  topic: incoming-messages-routing
  routes:
    rules:
      - match: event.data.type == "dapr.demo.type2"
        path: /handletype2
    # There is no default route in this case.
    # default: /messagehandler
scopes:
- receiver2
```

Instead of `routes.default` (challenge 1), this subscription has a `routes.rules` list. Rules in YAML are evaluated **in the order they're listed**, so there's no priority field to set. The subscription is scoped to `receiver2`, whose code is now just an endpoint with no Dapr attributes at all:

```csharp,nocopy
app.MapPost("/handletype2", (
    TinyMessage message) => {
    Console.WriteLine($"Type2 - Received message {message.Id}: {message.Type}.");

    return Results.Accepted();
});
```

Note the commented-out `default:` line. Without a default route, a message that matches none of this subscriber's rules is **acknowledged and dropped** rather than delivered anywhere. That is a deliberate choice here, and it's the second common surprise with routing: a message silently vanishing usually means a subscription with rules but no default.

## 4. Run the applications

Start all three applications from the **Dapr CLI** window:

```bash,run
cd Demo6-Routing
dapr run -f .
```

> [!IMPORTANT]
> Wait until you see `Started Dapr with app id "receiver2".` before continuing — the Dapr CLI prints one such line per app, and `receiver2` is the last one to start.

### Publish a type1 message

```curl,run
curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"66666666-0000-0000-0000-000000000001","timeStamp":"2026-01-01T12:00:00Z","type":"dapr.demo.type1"}'
```

Expected application log statements:

```text,nocopy
== APP - sender == Sent message 66666666-0000-0000-0000-000000000001 with type dapr.demo.type1.
== APP - receiver1 == Type1 - Received message 66666666-0000-0000-0000-000000000001: dapr.demo.type1.
```

`receiver1` handled it, and `receiver2` logged nothing — its only rule matches `dapr.demo.type2` and it has no default route.

### Publish a type2 message

```curl,run
curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"66666666-0000-0000-0000-000000000002","timeStamp":"2026-01-01T12:00:00Z","type":"dapr.demo.type2"}'
```

Expected application log statements:

```text,nocopy
== APP - sender == Sent message 66666666-0000-0000-0000-000000000002 with type dapr.demo.type2.
== APP - receiver2 == Type2 - Received message 66666666-0000-0000-0000-000000000002: dapr.demo.type2.
```

This time `receiver2` handled it and `receiver1` stayed quiet. Same topic, same publisher, different destination.

### Publish a type1 message with a large amount

```curl,run
curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"66666666-0000-0000-0000-000000000003","timeStamp":"2026-01-01T12:00:00Z","type":"dapr.demo.type1","amount":100}'
```

Expected application log statements:

```text,nocopy
== APP - sender == Sent message 66666666-0000-0000-0000-000000000003 with type dapr.demo.type1.
== APP - receiver1 == Large amount - Received message 66666666-0000-0000-0000-000000000003: dapr.demo.type1.
```

Both of `receiver1`'s rules matched this message, and the higher-priority one (`PRIORITY100`) won, so `/handlelargeamount` handled it instead of `/handletype1`.

Stop the applications by pressing `Ctrl+C` in the **Dapr CLI** window, then go back up one folder:

```bash,run
cd ..
```

## 5. What routing is and isn't

Routing decides **which endpoint of a subscriber** receives a message. It does not decide **which subscribers** receive it — each subscription is evaluated independently, so two subscribers whose rules both match will both get a copy. Filtering messages out of a subscriber entirely is what an absent default route does, as `receiver2` demonstrated.

For the full expression syntax and more examples, see [Message routing](https://docs.dapr.io/developing-applications/building-blocks/pubsub/howto-route-messages/) in the Dapr docs.

---

Every message so far has been accepted by its handler. In the final challenge you'll make a receiver reject one and follow where Dapr sends it.
