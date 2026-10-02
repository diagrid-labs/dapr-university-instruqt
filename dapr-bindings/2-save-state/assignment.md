Time to save your first row to Postgres without writing any database connection code. This challenge takes about 7 minutes.

> [!NOTE]
> Each step below has a section per language. Expand the one for the language you want to use, and stick with it for the whole challenge. All three apps do the same thing.

## 1. Inspect the binding component

Open `resources/postgres-binding.yaml` in the **Editor**. It sits inside the folder of your language (`python`, `dotnet` or `java`), and the file is identical in all three:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: postgres-binding
spec:
  type: bindings.postgresql
  version: v1
  metadata:
  - name: connectionString
    value: "host=localhost port=5432 user=postgres password=dapr123 dbname=venuedb sslmode=disable"
```

This is the only Dapr component this app uses. `type: bindings.postgresql` tells Dapr which binding implementation to load, and `connectionString` is the only thing it needs to know to reach the `dapr_postgres` container from challenge 1.

## 2. Inspect the exec operation

<details>
   <summary><b>Python</b></summary>

Open `python/app.py` and look at lines 33-48:

```python,nocopy
@app.post("/bookings")
def create_booking(booking: Booking):
    """Save a booking with the binding's "exec" operation (an INSERT)."""
    with DaprClient() as client:
        response = client.invoke_binding(
            binding_name=BINDING_NAME,
            operation="exec",
            data=b"",
            binding_metadata={
                "sql": "INSERT INTO bookings (venue, event_date) VALUES ($1, $2)",
                "params": json.dumps([booking.venue, booking.event_date]),
            },
        )
    rows_affected = response.binding_metadata.get("rows-affected")
    logging.info("Inserted booking for %s on %s (rows-affected=%s)", booking.venue, booking.event_date, rows_affected)
    return {"status": "saved", "rows_affected": rows_affected}
```

`invoke_binding` is the one call the Bindings API revolves around. `binding_name` picks the component from the YAML you just read, and `operation="exec"` tells the Postgres binding to run a write statement. The response metadata comes back in `response.binding_metadata`, and `rows-affected` tells you how many rows the INSERT touched.

</details>

<details>
   <summary><b>.NET</b></summary>

Open `dotnet/BookingsService.cs` and look at lines 26-35:

```csharp,nocopy
/// <summary>Save a booking with the binding's "exec" operation (an INSERT).</summary>
public async Task<string?> SaveBookingAsync(string venue, string eventDate)
{
    var request = new BindingRequest(BindingName, "exec");
    request.Metadata["sql"] = "INSERT INTO bookings (venue, event_date) VALUES ($1, $2)";
    request.Metadata["params"] = JsonSerializer.Serialize(new[] { venue, eventDate });

    var response = await _daprClient.InvokeBindingAsync(request);
    return response.Metadata.TryGetValue("rows-affected", out var rowsAffected) ? rowsAffected : null;
}
```

`InvokeBindingAsync` is the one call the Bindings API revolves around. The `BindingRequest` names the component from the YAML you just read, and `"exec"` tells the Postgres binding to run a write statement. The response metadata comes back in `response.Metadata`, and `rows-affected` tells you how many rows the INSERT touched.

</details>

<details>
   <summary><b>Java</b></summary>

Open `java/src/main/java/io/diagrid/quickstart/bindings/venuebookings/BookingsService.java` and look at lines 37-43:

```java,nocopy
/** Save a booking with the binding's "exec" operation (an INSERT). */
public void saveBooking(String venue, String eventDate) throws Exception {
    Map<String, String> metadata = new HashMap<>();
    metadata.put("sql", "INSERT INTO bookings (venue, event_date) VALUES ($1, $2)");
    metadata.put("params", objectMapper.writeValueAsString(new String[] { venue, eventDate }));
    daprClient.invokeBinding(BINDING_NAME, "exec", new byte[0], metadata).block();
}
```

`invokeBinding` is the one call the Bindings API revolves around. `BINDING_NAME` picks the component from the YAML you just read, and `"exec"` tells the Postgres binding to run a write statement.

> [!NOTE]
> The Java SDK only returns the response payload from `invokeBinding`. It doesn't expose the response metadata, so unlike the Python and .NET versions, this app can't report how many rows the INSERT affected.

</details>

In all three languages the SQL and its parameters travel in the request **metadata**, not in the data payload. That's specific to how the Postgres binding reads its request. `$1` and `$2` are positional placeholders, filled in order by the `params` array.

## 3. Run the app

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

## 4. Save a booking

Use the **Terminal 2** window.

<details>
   <summary><b>Python</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "event_date": "2026-03-15"}'
```

You should get back:

```text,nocopy
{"status":"saved","rows_affected":"1"}
```

</details>

<details>
   <summary><b>.NET</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "eventDate": "2026-03-15"}'
```

You should get back:

```text,nocopy
{"status":"saved","rows_affected":"1"}
```

</details>

<details>
   <summary><b>Java</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "eventDate": "2026-03-15"}'
```

You should get back:

```text,nocopy
{"status":"saved"}
```

</details>

## 5. Verify it landed in Postgres

```bash,run
docker exec dapr_postgres psql -U postgres -d venuedb -c "SELECT * FROM bookings;"
```

You should see the row you just inserted, even though the app never opened a Postgres connection itself.

## 6. Stop the app

Use `Ctrl+C` in the **Terminal** window to stop the app before moving on.

---

You've saved data to Postgres through a Dapr binding. Let's move on to challenge 3 where you'll read it back with the same binding.
