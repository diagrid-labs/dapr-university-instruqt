Now let's read that data back, through the exact same binding you just used to save it. This challenge takes about 6 minutes.

> [!NOTE]
> Each step below has a section per language. Expand the one for the language you want to use. All three apps do the same thing, and they all share the same Postgres database, so it doesn't matter if you pick a different language than in the last challenge.

## 1. Inspect the query operation

<details>
   <summary><b>Python</b></summary>

Open `python/app.py` and look at lines 51-67:

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

</details>

<details>
   <summary><b>.NET</b></summary>

Open `dotnet/BookingsService.cs` and look at lines 37-53:

```csharp,nocopy
/// <summary>Read every booking back with the same binding's "query" operation (a SELECT).</summary>
public async Task<List<Booking>> ListBookingsAsync()
{
    var request = new BindingRequest(BindingName, "query");
    request.Metadata["sql"] = "SELECT id, venue, event_date FROM bookings ORDER BY id";
    request.Metadata["params"] = "[]";

    var response = await _daprClient.InvokeBindingAsync(request);
    var json = Encoding.UTF8.GetString(response.Data.Span);
    var rows = string.IsNullOrEmpty(json)
        ? new List<List<JsonElement>>()
        : JsonSerializer.Deserialize<List<List<JsonElement>>>(json) ?? new List<List<JsonElement>>();

    return rows
        .Select(row => new Booking(row[1].GetString()!, row[2].GetString()!) { Id = row[0].GetInt32() })
        .ToList();
}
```

</details>

<details>
   <summary><b>Java</b></summary>

Open `java/src/main/java/io/diagrid/quickstart/bindings/venuebookings/BookingsService.java` and look at lines 45-59:

```java,nocopy
/** Read every booking back with the same binding's "query" operation (a SELECT). */
public List<Booking> listBookings() throws Exception {
    Map<String, String> metadata = new HashMap<>();
    metadata.put("sql", "SELECT id, venue, event_date FROM bookings ORDER BY id");
    metadata.put("params", "[]");
    byte[] response = daprClient.invokeBinding(BINDING_NAME, "query", new byte[0], metadata).block();
    if (response == null || response.length == 0) {
        return List.of();
    }
    List<List<Object>> rows = objectMapper.readValue(response, new TypeReference<List<List<Object>>>() {
    });
    return rows.stream()
            .map(row -> new Booking(((Number) row.get(0)).intValue(), (String) row.get(1), (String) row.get(2)))
            .collect(Collectors.toList());
}
```

</details>

Compare this to the exec operation from the last challenge. Same binding name, same component, same YAML file. The only things that changed are the operation (`query` instead of `exec`) and the SQL statement.

The response is different too. `query` doesn't give you a count of affected rows, it gives you the rows themselves, as a JSON array. Each row is a plain array of values in column order, `[id, venue, event_date]`, not an object with column names. So the app has to know the column order itself to turn each row back into something readable.

## 2. Run the app

Use the **Terminal** window.

<details>
   <summary><b>Python</b></summary>

```bash,run
cd python
```

```bash,run
uv run dapr run --app-id venue-bookings --resources-path ./resources -- python app.py
```

Wait until you see `Uvicorn running on http://0.0.0.0:8006` before continuing.

</details>

<details>
   <summary><b>.NET</b></summary>

```bash,run
cd dotnet
```

```bash,run
dapr run --app-id venue-bookings --resources-path ./resources -- dotnet run
```

Wait until you see `Now listening on: http://0.0.0.0:8006` before continuing.

</details>

<details>
   <summary><b>Java</b></summary>

```bash,run
cd java
```

```bash,run
dapr run --app-id venue-bookings --resources-path ./resources -- mvn spring-boot:run
```

Wait until you see `Tomcat started on port 8006` before continuing.

</details>

## 3. Query your bookings

Use the **Terminal 2** window:

```bash,run
curl http://localhost:8006/bookings
```

You should see the booking you saved in challenge 2:

<details>
   <summary><b>Python</b></summary>

```text,nocopy
{"bookings":[{"id":1,"venue":"Grand Ballroom","event_date":"2026-03-15T00:00:00Z"}]}
```

</details>

<details>
   <summary><b>.NET</b></summary>

```text,nocopy
{"bookings":[{"venue":"Grand Ballroom","eventDate":"2026-03-15T00:00:00Z","id":1}]}
```

</details>

<details>
   <summary><b>Java</b></summary>

```text,nocopy
{"bookings":[{"id":1,"venue":"Grand Ballroom","eventDate":"2026-03-15T00:00:00Z"}]}
```

</details>

Notice the date. In Postgres it's a plain `DATE`, and psql showed `2026-03-15` in the last challenge. The binding hands it back as a timestamp string instead, `2026-03-15T00:00:00Z`. The binding returns raw values from the database driver, and the app decides what to do with them.

## 4. Save one more and query again

Save a second booking using the **Terminal 2** window.

<details>
   <summary><b>Python</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "event_date": "2026-04-02"}'
```

</details>

<details>
   <summary><b>.NET</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "eventDate": "2026-04-02"}'
```

</details>

<details>
   <summary><b>Java</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "eventDate": "2026-04-02"}'
```

</details>

Then query again:

```bash,run
curl http://localhost:8006/bookings
```

Now both bookings come back, in the order they were inserted.

## 5. Stop the app

Use `Ctrl+C` in the **Terminal** window to stop the app.

## 6. Recap

- The Bindings API lets your app call an external system through a generic binding call, with no client library for that system in your code. The call looks slightly different in each language SDK, but it's the same idea.
- Postgres only has an output binding. There's no separate input binding to "trigger" a query, your app calls it, the same way it calls the write operation.
- One component, two operations: `exec` for INSERT/UPDATE/DELETE, `query` for SELECT. The SQL and its parameters travel in the request metadata, not the data payload.
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
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building with Dapr.
