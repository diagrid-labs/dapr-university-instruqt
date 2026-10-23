Time to save your first row to Postgres. This challenge takes about 7 minutes.

Expand the section for your language at each step.

## 1. Inspect the binding component

Open `resources/postgres-binding.yaml` in the **Editor**. This shared folder sits beside `python`, `dotnet` and `java`.

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

`bindings.postgresql` selects the component implementation. The connection string points at the `dapr_postgres` container from challenge 1. All three apps use this one file.

## 2. Inspect the exec operation

<details>
   <summary><b>Python</b></summary>

Open `python/app.py` and find the save method:

```python,nocopy
@app.post("/bookings", response_model=SaveBookingResponse)
def create_booking(booking: BookingRequest, client: DaprDependency):
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
    logger.info(
        "Inserted booking for %s on %s (rows-affected=%s)",
        booking.venue,
        booking.event_date,
        rows_affected,
    )
    return SaveBookingResponse(status="saved", rows_affected=rows_affected)
```

The SQL and its parameters are passed in request metadata. `$1` and `$2` are filled from the JSON array in `params`. FastAPI supplies the Dapr client created at startup. The same client serves every request and closes at shutdown. The `rows-affected` response metadata tells you how many rows the INSERT changed.

</details>

<details>
   <summary><b>.NET</b></summary>

Open `dotnet/src/VenueBookings/BookingsService.cs` and find the save method:

```csharp,nocopy
    public async Task<string?> SaveBookingAsync(string venue, string eventDate)
    {
        var request = new BindingRequest(BindingName, "exec");
        request.Metadata["sql"] = "INSERT INTO bookings (venue, event_date) VALUES ($1, $2)";
        request.Metadata["params"] = JsonSerializer.Serialize(new[] { venue, eventDate });

        var response = await daprClient.InvokeBindingAsync(request);
        return response.Metadata.TryGetValue("rows-affected", out var rowsAffected) ? rowsAffected : null;
    }
```

The SQL and its parameters are passed in request metadata. `$1` and `$2` are filled from the JSON array in `params`. The `rows-affected` response metadata tells you how many rows the INSERT changed.

</details>

<details>
   <summary><b>Java</b></summary>

Open `java/src/main/java/io/diagrid/quickstart/bindings/venuebookings/BookingsService.java` and find the save method:

```java,nocopy
    public void saveBooking(String venue, String eventDate) {
        Map<String, String> metadata = Map.of(
                "sql", "INSERT INTO bookings (venue, event_date) VALUES ($1, $2)",
                "params", objectMapper.writeValueAsString(new String[] { venue, eventDate }));
        daprClient.invokeBinding(BINDING_NAME, "exec", new byte[0], metadata).block();
    }
```

The SQL and its parameters are passed in request metadata. `$1` and `$2` are filled from the JSON array in `params`. The Java SDK returns the payload only, so this save response cannot include the affected-row metadata.

</details>

## 3. Run the app

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

## 4. Save a booking

Use **Terminal 2**.

<details>
   <summary><b>Python</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "event_date": "2026-03-15"}'
```

Expected response:

```json,nocopy
{"status":"saved","rows_affected":"1"}
```

</details>

<details>
   <summary><b>.NET</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "event_date": "2026-03-15"}'
```

Expected response:

```json,nocopy
{"status":"saved","rows_affected":"1"}
```

</details>

<details>
   <summary><b>Java</b></summary>

```bash,run
curl -X POST http://localhost:8006/bookings -H "Content-Type: application/json" -d '{"venue": "Grand Ballroom", "eventDate": "2026-03-15"}'
```

Expected response:

```json,nocopy
{"status":"saved"}
```

</details>

Python and .NET use snake_case JSON, including `event_date` and `rows_affected`. Java uses camelCase, including `eventDate`.

## 5. Verify the row in Postgres

```bash,run
docker exec dapr_postgres psql -U postgres -d venuedb -c "SELECT * FROM bookings;"
```

You should see the row you just inserted. The application sent SQL to Dapr, and Dapr ran it against Postgres.

## 6. Stop the app

Press `Ctrl+C` in **Terminal** before continuing.

---

You've saved data through the binding. In challenge 3 you'll query it through the same component.
