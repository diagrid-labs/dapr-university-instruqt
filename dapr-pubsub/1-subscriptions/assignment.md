Welcome to the *Dapr Pub/Sub messaging in depth* learning track! Publishing a message and receiving it somewhere else is the easy part of pub/sub messaging — the interesting questions start right after. This first challenge answers one of them: **how does a service declare what it subscribes to?** Dapr gives you three answers, and you'll use all of them. This challenge takes about 8 minutes to complete.

## 1. The demo applications

The `dapr-pub-sub-deep-dive` repository has been cloned for you. Use the *Editor* tab to explore it. Every challenge in this track uses one `DemoN-...` folder, and every folder follows the same shape:

- A **`SenderService`** — an ASP.NET Core app with a `/send` endpoint that publishes a message with the Dapr Pub/Sub API.
- One or more **`ReceiverService`** apps that subscribe to a topic and log what they receive.
- A **`Resources`** folder with the Dapr component and subscription YAML files.
- A **`dapr.yaml`** [Multi-App Run](https://docs.dapr.io/developing-applications/local-development/multi-app-dapr-run/multi-app-overview/) file, so a single `dapr run -f .` starts every app in the folder with its own sidecar.

The message being passed around is deliberately tiny — open `Demo1-Declarative/SenderService/Program.cs` and you'll find it at the bottom of the file:

```csharp,nocopy
record TinyMessage(Guid Id, DateTimeOffset TimeStamp);
```

The broker is a component, not a code dependency. Open `Demo1-Declarative/Resources/pubsub-redis.yaml`:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: demo1-pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
```

The `metadata.name` (`demo1-pubsub`) is the name the application code refers to. The `spec.type` (`pubsub.redis`) is the broker — the Redis instance that `dapr init` started for you.

> [!NOTE]
> Nothing in the application code names Redis. Swapping this file for a `pubsub.rabbitmq` or `pubsub.azure.servicebus.topics` component moves the same application onto a different broker without a code change. See the [supported pub/sub brokers](https://docs.dapr.io/reference/components-reference/supported-pubsub/) in the Dapr docs.

## 2. Verify the environment

> [!IMPORTANT]
> On the left you should see an *Editor* tab with the `dapr-pub-sub-deep-dive` repository, and two terminal windows at the bottom: **Dapr CLI** and **curl**. You'll start the applications in the **Dapr CLI** window and publish messages from the **curl** window.

Use the **Dapr CLI** window to confirm the Dapr CLI and runtime are ready:

```bash,run
dapr -v
```

Expected output:

```text,nocopy
CLI version: [[ Instruqt-Var key="DAPR_CLI_VERSION" hostname="dotnet-10-pubsub" ]]
Runtime version: [[ Instruqt-Var key="DAPR_RUNTIME_VERSION" hostname="dotnet-10-pubsub" ]]
```

The demo projects target `net10.0`, so check the SDK too:

```bash,run
dotnet --version
```

You should see a `10.0.x` version.

## 3. Declarative subscriptions

A **declarative** subscription lives outside your application, in a `Subscription` resource. The application only exposes an endpoint; it never mentions the topic or the broker.

Open `Demo1-Declarative/Resources/subscription.yaml`:

```yaml,nocopy
apiVersion: dapr.io/v2alpha1
kind: Subscription
metadata:
  name: receiver-sub
spec:
  pubsubname: demo1-pubsub
  topic: incoming-messages
  routes:
    default: /messagehandler
scopes:
- receiver
```

- `spec.pubsubname` and `spec.topic` say *what* to subscribe to.
- `spec.routes.default` says which endpoint to deliver to.
- `scopes` limits the subscription to the app with app ID `receiver`, so other apps sharing the same `Resources` folder don't get it.

Now open `Demo1-Declarative/ReceiverService/Program.cs`:

```csharp,nocopy
var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();
app.UseCloudEvents();

app.MapPost("/messagehandler", (
    TinyMessage message) =>
{
    Console.WriteLine($"Received message {message.Id}.");

    return Results.Accepted();
});

app.Run();
```

There is no Dapr subscription code at all — just a POST endpoint and `app.UseCloudEvents()`, which unwraps the CloudEvents envelope so the handler binds a `TinyMessage` directly. You'll take a closer look at that envelope in the next challenge.

Start both applications from the **Dapr CLI** window:

```bash,run
cd Demo1-Declarative
dapr run -f .
```

> [!IMPORTANT]
> Wait until you see `Started Dapr with app id "receiver".` before continuing — the Dapr CLI prints one such line per app, and `receiver` is the last one to start.

Now publish a message from the **curl** window:

```curl,run
curl -i --request POST --url http://localhost:5231/send --header 'content-type: application/json' --data '{"id":"11111111-1111-1111-1111-111111111111","timeStamp":"2026-01-01T12:00:00Z"}'
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - sender == Sent message 11111111-1111-1111-1111-111111111111.
== APP - receiver == Received message 11111111-1111-1111-1111-111111111111.
```

> [!NOTE]
> The `SenderService` also has a `/sendasbytes` endpoint that uses `PublishByteEventAsync` to publish a raw byte payload instead of a serialized object. Have a look at it in the *Editor* tab if you're curious.

Stop the applications by pressing `Ctrl+C` in the **Dapr CLI** window, then go back up one folder:

```bash,run
cd ..
```

## 4. Programmatic subscriptions

A **programmatic** subscription is declared in the application code with a `[Topic]` attribute. Dapr discovers it by calling a `/dapr/subscribe` endpoint on the app at startup.

Open `Demo2-Programmatic/ReceiverService/Program.cs`:

```csharp,nocopy
var app = builder.Build();
app.UseCloudEvents();
app.MapSubscribeHandler();

const string PUBSUB_NAME = "demo2-pubsub";
const string TOPIC_NAME = "incoming-messages-programmatic";

app.MapPost("/messagehandler",
    [Topic(PUBSUB_NAME, TOPIC_NAME)] (TinyMessage message) => {
    Console.WriteLine($"Received message {message.Id} via programmatic subscription.");

    return Results.Accepted();
});
```

Two things make this work:

- `app.MapSubscribeHandler()` registers the `/dapr/subscribe` endpoint that the Dapr sidecar calls to discover subscriptions.
- `[Topic(PUBSUB_NAME, TOPIC_NAME)]` on the endpoint is what that endpoint reports.

Notice that `Demo2-Programmatic/Resources` contains only the pub/sub component — there is no `subscription.yaml`.

Start the applications from the **Dapr CLI** window:

```bash,run
cd Demo2-Programmatic
dapr run -f .
```

Publish a message from the **curl** window — note the different port, each demo uses its own:

```curl,run
curl -i --request POST --url http://localhost:5233/send --header 'content-type: application/json' --data '{"id":"22222222-2222-2222-2222-222222222222","timeStamp":"2026-01-01T12:00:00Z"}'
```

Expected application log statements:

```text,nocopy
== APP - sender == Sent message 22222222-2222-2222-2222-222222222222.
== APP - receiver == Received message 22222222-2222-2222-2222-222222222222 via programmatic subscription.
```

Stop the applications with `Ctrl+C` in the **Dapr CLI** window and go back up one folder:

```bash,run
cd ..
```

## 5. Streaming subscriptions

Declarative and programmatic subscriptions are both *static*: Dapr pushes messages to an HTTP endpoint, and the subscription exists for as long as the app does. A **streaming** subscription inverts that. The application opens a bidirectional gRPC stream to its sidecar, receives messages over it, and creates and disposes subscriptions at runtime. No endpoint is exposed, so nothing needs to be reachable from outside.

Open `Demo3-Streaming/ReceiverService/Program.cs`:

```csharp,nocopy
Task<TopicResponseAction> HandleMessageAsync(
    TopicMessage message,
    CancellationToken cancellationToken = default)
{
    try
    {
        //Do something with the message
        Console.WriteLine($"Received {Encoding.UTF8.GetString(message.Data.Span)} via streaming subscription.");
        return Task.FromResult(TopicResponseAction.Success);
    }
    catch
    {
        return Task.FromResult(TopicResponseAction.Retry);
    }
}

var messagingClient = app.Services.GetRequiredService<DaprPublishSubscribeClient>();

var cancellationTokenSource = new CancellationTokenSource(TimeSpan.FromSeconds(30));
var subscriptionOptions = new DaprSubscriptionOptions(
    new MessageHandlingPolicy(
        TimeoutDuration: TimeSpan.FromSeconds(10),
        DefaultResponseAction: TopicResponseAction.Retry));
var subscription = await messagingClient.SubscribeAsync(
    PUBSUB_NAME,
    TOPIC_NAME,
    subscriptionOptions,
    HandleMessageAsync,
    cancellationTokenSource.Token);

await Task.Delay(TimeSpan.FromMinutes(1));

//When you're done with the subscription, simply dispose of it
await subscription.DisposeAsync();
```

The differences worth noticing:

- The handler **returns a `TopicResponseAction`** (`Success`, `Retry`, or `Drop`) instead of an HTTP status code — the acknowledgement is explicit.
- A `MessageHandlingPolicy` sets a per-message timeout and the action to take when the handler doesn't answer in time.
- `SubscribeAsync` returns a subscription that you `DisposeAsync` when you're done. This one is short-lived on purpose: the cancellation token cancels after **30 seconds** and the app exits after a minute.

> [!IMPORTANT]
> Because the subscription lives for only 30 seconds, publish your message promptly once you see `Started Dapr with app id "receiver".`. If you're too late, stop the apps with `Ctrl+C` and start them again.

Start the applications from the **Dapr CLI** window:

```bash,run
cd Demo3-Streaming
dapr run -f .
```

Publish a message from the **curl** window:

```curl,run
curl -i --request POST --url http://localhost:5235/send --header 'content-type: application/json' --data '{"id":"33333333-3333-3333-3333-333333333333","timeStamp":"2026-01-01T12:00:00Z"}'
```

Expected application log statements. Note that the handler logs the raw JSON payload, because a streaming subscription hands you the message bytes rather than a deserialized object:

```text,nocopy
== APP - sender == Sent message 33333333-3333-3333-3333-333333333333.
== APP - receiver == Received {"id":"33333333-3333-3333-3333-333333333333","timeStamp":"2026-01-01T12:00:00+00:00"} via streaming subscription.
```

> [!NOTE]
> After about a minute the `receiver` app exits on its own and the Dapr CLI reports that it stopped. That's the code above finishing its `Task.Delay` and disposing the subscription — a reminder that a streaming subscription's lifetime is entirely in your hands.

Stop the applications with `Ctrl+C` in the **Dapr CLI** window and go back up one folder:

```bash,run
cd ..
```

## 6. Which subscription type should you use?

| | Declarative | Programmatic | Streaming |
|---|---|---|---|
| Declared in | `Subscription` YAML resource | `[Topic]` attribute in code | Code, at runtime |
| Transport | HTTP push to an endpoint | HTTP push to an endpoint | Bidirectional gRPC stream |
| Changeable without a redeploy | Yes | No | Yes |
| App must expose an endpoint | Yes | Yes | No |
| Acknowledgement | HTTP status code | HTTP status code | `TopicResponseAction` |

Declarative subscriptions keep messaging configuration out of the code, which is why most of the rest of this track leans on them. Programmatic subscriptions keep it next to the handler. Streaming subscriptions suit clients that come and go, or that can't accept inbound traffic. For more detail, read [Declarative, streaming and programmatic subscription types](https://docs.dapr.io/developing-applications/building-blocks/pubsub/subscription-methods/) in the Dapr docs.

> [!IMPORTANT]
> Click the *Check* button to verify the Dapr environment before continuing.

---

You've now used all three Dapr subscription types. In the next challenge you'll look inside the message itself and read the CloudEvents envelope that Dapr wraps around every payload.
