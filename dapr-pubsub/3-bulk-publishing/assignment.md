So far every message has travelled on its own: one HTTP call to the sidecar, one message on the topic. When a service produces messages in groups — a batch import, a set of line items, a window of telemetry — that's a lot of round-trips for no reason. This challenge uses the **bulk publish** API to send a set of messages in one request, and shows what a **bulk subscription** does on the receiving end. This challenge takes about 4 minutes to complete.

## 1. Publishing a batch

Open `Demo4-Bulk/SenderService/Program.cs` in the *Editor* tab. The `/send` endpoint now accepts a `List<TinyMessage>` and calls `BulkPublishEventAsync`:

```csharp,nocopy
app.MapPost("/send", async (
    List<TinyMessage> messages,
    DaprClient daprClient) => {

    var bulkPublishResponse = await daprClient.BulkPublishEventAsync(
            PubSubComponentName,
            TopicName,
            messages);
```

The interesting part is the response. A bulk publish is **not** atomic: some entries can succeed while others fail, so the response reports the failures individually.

```csharp,nocopy
if (bulkPublishResponse.FailedEntries.Count > 0)
{
    Console.WriteLine("Some events failed to be published!");

    foreach (var failedEntry in bulkPublishResponse.FailedEntries)
    {
        Console.WriteLine($"EntryId : {failedEntry.Entry.EntryId} Error message : {failedEntry.ErrorMessage}");
    }
    ...
}
else
{
    Console.WriteLine("Published multiple events!");
    ...
}
```

Each message gets an **entry ID** so you can tell which ones didn't make it and retry just those. Ignoring `FailedEntries` is the most common mistake with this API — a bulk publish that returns without an exception has not necessarily published everything.

> [!NOTE]
> Not every broker supports bulk publishing natively. When a component doesn't, Dapr still accepts the single bulk request and publishes the entries to the broker one by one, so your code doesn't have to care. Redis Streams — the broker in this sandbox — is one of those, so the win here is the reduced number of app-to-sidecar calls.

## 2. Two subscribers, two delivery styles

This demo has two receivers subscribed to the same topic.

**`ReceiverService1`** is an ordinary subscriber. It uses the declarative subscription in `Demo4-Bulk/Resources/subscription1.yaml` and handles one message per request:

```csharp,nocopy
app.MapPost("/messagehandler", (
    TinyMessage message) =>
{
    Console.WriteLine($"Received message {message.Id}.");

    return Results.Accepted();
});
```

**`ReceiverService2`** opts into batched delivery. Open `Demo4-Bulk/ReceiverService2/Program.cs`:

```csharp,nocopy
const string PUBSUB_NAME = "demo4-pubsub";
const string TOPIC_NAME = "incoming-messages-bulk";
const int MAX_MESSAGE_COUNT = 50; // Optional - default is 100
const int MAX_DURATION_MS = 500; // Optional - default is 1000ms

app.MapPost("/messagehandler",
    [BulkSubscribe(TOPIC_NAME, MAX_MESSAGE_COUNT, MAX_DURATION_MS)]
    [Topic(PUBSUB_NAME, TOPIC_NAME)] (BulkSubscribeMessage<TinyMessage> bulkMessage) =>
{
    Console.WriteLine($"Received {bulkMessage.Entries.Count} messages.");

    List<BulkSubscribeAppResponseEntry> responseEntries = new List<BulkSubscribeAppResponseEntry>();

    foreach (var message in bulkMessage.Entries)
    {
        try
        {
            // Process each message
            responseEntries.Add(
                new BulkSubscribeAppResponseEntry(
                    message.EntryId,
                    BulkSubscribeAppResponseStatus.SUCCESS));
        }
        catch (Exception)
        {
            responseEntries.Add(
                new BulkSubscribeAppResponseEntry(
                    message.EntryId,
                    BulkSubscribeAppResponseStatus.RETRY));
        }
    }
    return new BulkSubscribeAppResponse(responseEntries);
});
```

Three things to take from this:

- **`[BulkSubscribe]`** turns the subscription into a batched one. `MAX_MESSAGE_COUNT` caps the batch size and `MAX_DURATION_MS` caps how long Dapr waits to fill a batch — whichever limit is reached first closes the batch. So a batch is *at most* 50 messages and *at most* 500ms old.
- The handler receives a **`BulkSubscribeMessage<TinyMessage>`** with an `Entries` collection instead of a single message.
- The response is **per entry**. Unlike a regular subscriber, which acknowledges a whole request with one HTTP status code, a bulk subscriber marks each entry `SUCCESS` or `RETRY` individually — so one bad message in a batch doesn't force the other 49 to be redelivered.

## 3. Run the applications

Start all three applications from the **Dapr CLI** window:

```bash,run
cd Demo4-Bulk
dapr run -f .
```

> [!IMPORTANT]
> Wait until you see `Started Dapr with app id "receiver2".` before continuing — the Dapr CLI prints one such line per app, and `receiver2` is the last one to start.

Publish three messages in a single request from the **curl** window. Note the JSON array:

```curl,run
curl -i --request POST --url http://localhost:5237/send --header 'content-type: application/json' --data '[{"id":"aaaaaaaa-0000-0000-0000-000000000001","timeStamp":"2026-01-01T12:00:00Z"},{"id":"aaaaaaaa-0000-0000-0000-000000000002","timeStamp":"2026-01-01T12:00:01Z"},{"id":"aaaaaaaa-0000-0000-0000-000000000003","timeStamp":"2026-01-01T12:00:02Z"}]'
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - sender == Published multiple events!
== APP - receiver1 == Received message aaaaaaaa-0000-0000-0000-000000000001.
== APP - receiver1 == Received message aaaaaaaa-0000-0000-0000-000000000002.
== APP - receiver1 == Received message aaaaaaaa-0000-0000-0000-000000000003.
== APP - receiver2 == Received 3 messages.
```

One publish request, three messages on the topic, and two subscribers that saw them very differently:

- `receiver1` was invoked **three times**, once per message.
- `receiver2` was invoked **once** with all three messages in a batch.

> [!NOTE]
> `receiver1`'s three lines may appear in any order — the three messages are delivered concurrently, and a bulk publish makes no ordering promise. Likewise, `receiver2` may report fewer than 3 messages across two log lines (for example `Received 2 messages.` followed by `Received 1 messages.`). That's the 500ms `MAX_DURATION_MS` window closing a batch before the third message arrived, and it's exactly the trade-off a bulk subscription makes: larger batches mean fewer invocations but more latency for the first message in each batch.

Stop the applications by pressing `Ctrl+C` in the **Dapr CLI** window, then go back up one folder:

```bash,run
cd ..
```

## 4. Bulk publish and bulk subscribe are independent

It's worth being explicit about this, because it's easy to conflate the two:

| | Controls | Set by |
|---|---|---|
| **Bulk publish** | How many messages leave the publisher per request | The publisher, by calling `BulkPublishEventAsync` |
| **Bulk subscribe** | How many messages arrive at the subscriber per invocation | The subscriber, with `[BulkSubscribe]` |

A bulk publish delivers to ordinary subscribers just fine, and a bulk subscriber batches messages that were published one at a time. You saw both in the run above. Read more in [Publish and subscribe to bulk messages](https://docs.dapr.io/developing-applications/building-blocks/pubsub/pubsub-bulk/) in the Dapr docs.

---

Every subscriber so far has received every message on its topic. In the next challenge you'll send different messages to different handlers based on what's inside them.
