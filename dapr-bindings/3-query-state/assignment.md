Now let's read that data back, through the exact same binding you just used to save it. This challenge takes about 6 minutes.

## 1. Inspect the query operation

Open `app.py` and look at lines 51-67:

```python,nocopy
@app.get("/bookings")
def list_bookings():
    """Read every booking back with the same binding's "query" operation (a SELECT)."""
    with DaprClient() as client:
        response = client.invoke_binding(
            binding_name=BINDING_NAME,
            operation="query",
            data=b"",
            binding_metadata={
                "sql": "SELECT id, venue, event_date FROM bookings ORDER BY id",
                "params": "[]",
            },
        )
    rows = json.loads(response.data) if response.data else []
    bookings = [{"id": row[0], "venue": row[1], "event_date": row[2]} for row in rows]
    logging.info("Queried %d booking(s)", len(bookings))
    return {"bookings": bookings}
```

Compare this to `create_booking` from the last challenge. Same `binding_name`, same component, same YAML file. The only things that changed are the `operation` (`query` instead of `exec`) and the SQL statement.

The response shape is different too. `query` doesn't return a `rows-affected` count, it returns the actual rows in `response.data`, as a JSON string. Each row comes back as a plain array of values in column order, `[id, venue, event_date]`, not a dict with column names, so `list_bookings` has to know the column order itself to turn it back into something readable.

## 2. Run the app

Use the **Terminal** window:

```bash,run
uv run dapr run --app-id venue-bookings --resources-path ./resources -- python app.py
```

Wait until you see `Uvicorn running on http://0.0.0.0:8006` before continuing.

## 3. Query your bookings

Use the **Terminal 2** window:

```bash,run
curl http://localhost:8006/bookings
```

You should see the booking you saved in challenge 2:

```text,nocopy
{"bookings":[{"id":1,"venue":"Grand Ballroom","event_date":"2026-03-15"}]}
```

## 4. Save one more and query again

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "event_date": "2026-04-02"}'
```

```bash,run
curl http://localhost:8006/bookings
```

Now both bookings come back, in the order they were inserted.

## 5. Stop the app

Use `Ctrl+C` in the **Terminal** window to stop the app.

## 6. Recap

- The Bindings API lets your app call an external system through a generic `invoke_binding` call, with no client library for that system in your code.
- Postgres only has an output binding. There's no separate input binding to "trigger" a query, your app calls it, the same way it calls the write operation.
- One component, two operations: `exec` for INSERT/UPDATE/DELETE, `query` for SELECT. The SQL and its parameters travel in `binding_metadata`, not `data`.
- Compare that to the State Store API: a fixed get/set/delete-by-key contract, the same shape no matter which state store backs it. Bindings trade that fixed shape for whatever operations the target system actually supports.

---

## Feedback and further learning

Congratulations! 🎉 You've completed the *Using the Dapr Bindings API with PostgreSQL* learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving it.

We have more ways for you to learn and share knowledge:

**Try another university track**
- [Dapr 101](https://www.diagrid.io/university/dapr-101)
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Read more**
- Read the [Dapr Bindings overview](https://docs.dapr.io/developing-applications/building-blocks/bindings/bindings-overview/).
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#bindings* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building with Dapr.
