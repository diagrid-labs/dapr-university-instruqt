# Dapr Pub/Sub messaging in depth

Publishing a message and receiving it somewhere else is the easy part of pub/sub messaging. The interesting questions come next: how does a service declare what it subscribes to? What does the message actually look like on the wire? How do you publish a hundred messages efficiently? How do you send different message types to different handlers? And what happens to a message your application refuses to process?

This hands-on track answers all five with the Dapr Pub/Sub API.

## What you'll build

You'll run a series of small .NET sender and receiver services from the [Dapr Pub/Sub Deep Dive](https://github.com/diagrid-labs/dapr-pub-sub-deep-dive) repository, each isolating one aspect of the Pub/Sub API. You publish messages with `curl` and watch them arrive — or deliberately not arrive — in the receiver logs. Every demo runs locally with the Dapr CLI against a Redis Streams message broker, and the broker is a swappable component, not a code dependency.

## What you'll learn

- The three Dapr subscription types — **declarative** (a `Subscription` YAML resource), **programmatic** (a `[Topic]` attribute in code), and **streaming** (a subscription created and torn down at runtime) — and the trade-offs between them.
- How Dapr wraps every published payload in a **CloudEvents** envelope, how to bind to the envelope instead of the data, and how to override attributes such as `type` with publish metadata.
- How the **bulk publish** API sends many messages in one request, and how a **bulk subscription** batches deliveries to the subscriber.
- How **content-based routing** dispatches messages to different endpoints using match expressions, with priorities deciding which rule wins.
- How **dead letter topics** and **resiliency policies** together decide whether a rejected message is retried, dropped, or parked for later inspection.

## Supported language

.NET

## Prerequisites

Familiarity with C# and basic .NET tooling is recommended. The sandbox comes preconfigured with Docker, the .NET 10 SDK, the Dapr CLI, and an initialized self-hosted Dapr environment — no local installation or cloud account is needed.
