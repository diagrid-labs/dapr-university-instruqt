# Name

Dapr Pub/Sub messaging in depth

## Url

dapr-pubsub

## Teaser

Go beyond a basic publish and subscribe: use all three Dapr subscription types, inspect the CloudEvents envelope, publish messages in bulk, route messages by content, and dead-letter the ones your app rejects.

Languages: .NET. Duration: 30 min.

## Time limit (minutes)

30

## Description

Publishing a message and receiving it somewhere else is the easy part of pub/sub messaging. The interesting questions come next: *how* does a service declare what it subscribes to, what does the message actually look like on the wire, how do you publish a hundred messages efficiently, how do you send different message types to different handlers, and what happens to a message your application refuses to process?

In this self-paced track you'll answer all of those with the Dapr Pub/Sub API and a set of small .NET sender and receiver services.

In this self-paced track, you'll learn:
- The three Dapr subscription types — declarative, programmatic, and streaming — and when to reach for each.
- How Dapr wraps every message in a CloudEvents envelope, and how to read and override its attributes.
- How to publish many messages in a single request with the bulk publish API, and how bulk subscriptions batch deliveries.
- How to route messages to different handlers based on their content, using match expressions and priorities.
- How dead letter topics and resiliency policies keep a poison message from blocking a topic.

You'll probably need around 28 minutes to complete the 5 challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
