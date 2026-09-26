# Using the Dapr Bindings API with PostgreSQL

The Bindings API lets a Dapr app read and write to an external system, like a database, a queue, or a webhook, without ever linking a client library for it. In this hands-on track you'll use it to save and query data in PostgreSQL.

## What you'll build

You'll run **Venue Bookings**, a small app with two endpoints. Both go through the same Dapr binding component to PostgreSQL, just with a different operation: one inserts a booking, the other reads them back.

## What you'll learn

- What the Bindings API is, and how it differs from the State Store API.
- Why PostgreSQL only has an output binding in Dapr, not an input binding, and what that means for how you read data back.
- How to save data with a binding's `exec` operation.
- How to query data with the same binding's `query` operation.

## Supported language

Python

## Prerequisites

Familiarity with Python is recommended. The sandbox comes preconfigured with Docker, Python, uv, Dapr, and a local PostgreSQL container. No API key is needed.
