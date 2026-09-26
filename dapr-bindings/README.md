# Name

Using the Dapr Bindings API with PostgreSQL

## Url

dapr-bindings

## Teaser

Save and query data in PostgreSQL through Dapr's Bindings API, without your app ever holding a database driver or a connection string in code.

Languages: Python. Duration: 20 min. No API key required.

## Time limit (minutes)

30

## Description

The Bindings API is how a Dapr app talks to an external system, like a database, a message queue, or a webhook, without linking a client library for it. In this self-paced track you'll use it to save and query data in PostgreSQL.

You'll work with **Venue Bookings**, a small app with two endpoints. Both go through the same Dapr binding component, just with a different operation: one inserts a row, the other selects them back.

In this self-paced track, you'll learn:
- What the Bindings API is, and how it differs from the State Store API.
- Why PostgreSQL only has an *output* binding in Dapr, and what that means in practice.
- How to save data with a binding's `exec` operation.
- How to read data back with the same binding's `query` operation.

You'll probably need around 20 minutes to complete the 3 challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
