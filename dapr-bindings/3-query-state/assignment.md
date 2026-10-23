Now read the data back through the same binding. This challenge takes about 6 minutes.

The apps share one database. You can use any of the three languages to read the booking you saved.

## 1. Inspect the query operation

<details>
   <summary><b>Python</b></summary>

Open `python/app.py` and find the query method:

```python,nocopy
@app.get("/bookings", response_model=BookingsResponse)
def list_bookings(client: DaprDependency):
    response = client.invoke_binding(
        binding_name=BINDING_NAME,
        operation="query",
        data=b"",
        binding_metadata={
            "sql": "SELECT id, venue, event_date::text FROM bookings ORDER BY id",
            "params": "[]",
        },
    )
    rows = json.loads(response.data) if response.data else []
    bookings = [Booking(id=row[0], venue=row[1], event_date=row[2]) for row in rows]
    logger.info("Queried %d booking(s)", len(bookings))
    return BookingsResponse(bookings=bookings)
```

</details>

<details>
   <summary><b>.NET</b></summary>

Open `dotnet/src/VenueBookings/BookingsService.cs` and find the query method:

```csharp,nocopy
    public async Task<List<Booking>> ListBookingsAsync()
    {
        var request = new BindingRequest(BindingName, "query");
        request.Metadata["sql"] = "SELECT id, venue, event_date::text FROM bookings ORDER BY id";
        request.Metadata["params"] = "[]";

        var response = await daprClient.InvokeBindingAsync(request);
        var rows = response.Data.IsEmpty
            ? []
            : JsonSerializer.Deserialize<List<List<JsonElement>>>(response.Data.Span) ?? [];

        return rows.Select(row => new Booking(
            row[0].GetInt32(), row[1].GetString()!, row[2].GetString()!)).ToList();
    }
```

</details>

<details>
   <summary><b>Java</b></summary>

Open `java/src/main/java/io/diagrid/quickstart/bindings/venuebookings/BookingsService.java` and find the query method:

```java,nocopy
    public List<Booking> listBookings() {
        Map<String, String> metadata = Map.of(
                "sql", "SELECT id, venue, event_date::text FROM bookings ORDER BY id",
                "params", "[]");
        byte[] response = daprClient.invokeBinding(BINDING_NAME, "query", new byte[0], metadata).block();
        if (response == null || response.length == 0) {
            return List.of();
        }
        List<List<Object>> rows = objectMapper.readValue(response, new TypeReference<List<List<Object>>>() {});
        return rows.stream()
                .map(row -> new Booking(((Number) row.get(0)).intValue(), (String) row.get(1), (String) row.get(2)))
                .toList();
    }
```

</details>

The operation is now `query`, and the SQL is a SELECT. The binding name and component file are unchanged.

The response contains arrays of values in column order: `[id, venue, event_date]`. Each app turns those arrays into named fields. An empty table produces `[]`.

The SELECT uses `event_date::text` to return a plain date such as `2026-03-15`. Without the cast, the database driver serializes the date as a timestamp.

## 2. Run the app

Use **Terminal**. Each terminal starts in `bindings/venue-bookings`. If yours is still inside a language folder from the last challenge, run `cd ..` first.

<details>
   <summary><b>Python</b></summary>

```bash,run
cd python
```

```bash,run
uv run dapr run --app-id venue-bookings --resources-path ../resources -- python app.py
```

Wait for `Uvicorn running on http://0.0.0.0:8006` before continuing.

</details>

<details>
   <summary><b>.NET</b></summary>

```bash,run
cd dotnet
```

```bash,run
dapr run --app-id venue-bookings --resources-path ../resources -- dotnet run --project src/VenueBookings
```

Wait for `Now listening on: http://0.0.0.0:8006` before continuing.

</details>

<details>
   <summary><b>Java</b></summary>

```bash,run
cd java
```

```bash,run
dapr run --app-id venue-bookings --resources-path ../resources -- bash ./mvnw spring-boot:run
```

Wait for `Tomcat started on port 8006` before continuing.

</details>

## 3. Query your bookings

Use **Terminal 2**:

```bash,run
curl http://localhost:8006/bookings
```

You should see the booking from challenge 2. The ID can differ if you've saved extra rows.

<details>
   <summary><b>Python</b></summary>

```json,nocopy
{"bookings":[{"id":1,"venue":"Grand Ballroom","event_date":"2026-03-15"}]}
```

</details>

<details>
   <summary><b>.NET</b></summary>

```json,nocopy
{"bookings":[{"id":1,"venue":"Grand Ballroom","event_date":"2026-03-15"}]}
```

</details>

<details>
   <summary><b>Java</b></summary>

```json,nocopy
{"bookings":[{"id":1,"venue":"Grand Ballroom","eventDate":"2026-03-15"}]}
```

</details>

## 4. Save one more and query again

Use **Terminal 2**.

<details>
   <summary><b>Python</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "event_date": "2026-04-02"}'
```

</details>

<details>
   <summary><b>.NET</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Rooftop Terrace", "event_date": "2026-04-02"}'
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

Both bookings should come back in the order they were inserted.

## 5. Stop the app

Press `Ctrl+C` in **Terminal**.

## 6. Recap

- Dapr connects to Postgres through one output binding.
- `exec` writes data and `query` reads it. Both pass SQL and parameters in metadata.
- Your app chooses the SQL and owns the schema. The State Store API instead offers a common contract for storing values by key.

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
