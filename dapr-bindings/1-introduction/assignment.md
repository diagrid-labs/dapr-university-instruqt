Welcome to **Using the Dapr Bindings API with PostgreSQL**. In this track you'll save and query data in Postgres without your app ever holding a database driver or a connection string in code. This first challenge takes about 7 minutes.

## What is the Bindings API?

Dapr's Bindings API lets your app talk to an external system, a database, a message queue, a webhook, almost anything, through a single, generic HTTP or gRPC call. Your app never links a client library for that system. Instead, it calls Dapr with an **operation** name and some data, and a Dapr component translates that into whatever the real system expects.

Bindings come in two directions:
- **Output binding**: your app calls out to the external system. You decide when it happens.
- **Input binding**: the external system calls into your app. Something like a Cron schedule or a message arriving triggers your code, on its own schedule, not yours.

## How is that different from the State Store API?

The State Store API is also a Dapr building block, and it can also be backed by a database. The difference is in the contract:

- The **State Store API** has a fixed shape: get, set, delete, and query, always by key. Every state store component, whether it's Redis or Postgres or CosmosDB, has to support that same shape.
- The **Bindings API** has no fixed shape. Each binding component defines its own operations. A Postgres binding supports `exec` and `query`. A blob storage binding supports `create`. A Twilio binding supports `create` to send a text message. The operations are whatever makes sense for that system.

So if all you need is key-based storage, the State Store API is the simpler fit. If you need something a key-value contract can't express, like running an arbitrary SQL statement, that's what the Bindings API is for.

## What you'll build

You'll run **Venue Bookings**, a small app with two endpoints. `POST /bookings` saves a booking, `GET /bookings` reads them back. Both go through the exact same Dapr binding to Postgres. There's no separate binding for reading versus writing.

The app exists in three languages: Python, .NET and Java. They do exactly the same thing. In challenges 2 and 3, expand the section for the language you want to use.

> [!NOTE]
> PostgreSQL only has an **output** binding in Dapr. There's no Postgres input binding, since nothing about a database can reach into your app and trigger it the way a Cron schedule or a queue message can. You'll see in challenges 2 and 3 that saving and querying both use the same output binding, just with a different operation.

## 1. Verify the sandbox

Use the **Terminal** window to confirm the Dapr CLI and runtime are ready:

```bash,run
dapr -v
```

> [!NOTE]
> You should see both a **CLI version** and a **Runtime version** listed. If the Runtime version is blank, run `dapr init` below to initialize it. If you run into any other blocking issue during this course, send me [an email](mailto:marc@diagrid.io) and we'll figure it out together.

```bash,run
dapr init
```

## 2. Verify the local Postgres container

```bash,run
docker ps -f name=dapr_postgres
```

You should see a container named `dapr_postgres` with status `Up`.

> [!IMPORTANT]
> Click the *Check* button to verify the sandbox before continuing.

---

You now know what the Bindings API is and how it differs from the State Store API. Let's move on to challenge 2 where you'll use it to save data to Postgres.
