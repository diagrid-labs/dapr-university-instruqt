# State API vs binding

In this lab, you'll save each reading twice into the same PostgreSQL database, once through the State API and once through the binding, and compare what each one gives you. This hands-on lab takes about 7 minutes to complete.

## Before you start

Open the **Dev Dashboard** tab and check the **Applications** page. If an application from the previous lab is still running, use the **Dapr CLI** window to stop it by pressing `Ctrl+C`. This demo uses the same ports.

This demo needs the `bindings-postgres` database container. If `docker ps` in the **curl** window doesn't list it, start it again with the block in the section *If the database is not running* of the previous lab.

## 1. Two components, one database

Dapr has a building block for storing data, the State API, and it supports PostgreSQL as a state store. So why use a binding at all? This demo lets you see both side by side.

Use the **Editor** tab and open the demo folder of your language: `dotnet/Demo3-StateVsBinding`, `python/demo3-state-vs-binding` or `java/demo3-state-vs-binding`. Open `statestore.yaml` in the `resources` folder of the demo:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.postgresql
  version: v1
  metadata:
  - name: connectionString
    value: "host=localhost port=5432 user=dapr password=dapr dbname=dapr sslmode=disable"
```

It is a state store of type `state.postgresql`, with the same connection string as `ship-db`. The `dapr.yaml` of the demo loads both: `ship-db` from `../resources` and `statestore` from `./resources`.

Open the code that writes a reading.

<details>
   <summary><b>.NET</b></summary>

Open `Program.cs` in the `dotnet/Demo3-StateVsBinding/Engineering` folder. The `/warp-core-scan` handler saves the reading with `daprClient.SaveStateAsync` under the key `reading-<readingId>`, then inserts it with the `exec` operation of `ship-db`. The `/state/{readingId}` endpoint reads it back with `daprClient.GetStateAsync`.

</details>

<details>
   <summary><b>Python</b></summary>

Open `app.py` in the `python/demo3-state-vs-binding/engineering` folder. The `/warp-core-scan` handler saves the reading with `save_state` under the key `reading-<readingId>`, then inserts it with the `exec` operation of `ship-db`. The `/state/{reading_id}` endpoint reads it back with `get_state`.

</details>

<details>
   <summary><b>Java</b></summary>

Open `ReadingController.java` in the `java/demo3-state-vs-binding/engineering/src/main/java/io/diagrid/university/bindings/engineering` folder. The `/warp-core-scan` handler saves the reading with `daprClient.saveState` under the key `reading-<readingId>`, then inserts it with the `exec` operation of `ship-db`. The `/state/{readingId}` endpoint reads it back with `daprClient.getState`.

</details>

The State API call holds no SQL at all, only a store name, a key and a value. The binding call holds the SQL of the `INSERT`.

## 2. Run the demo

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `bindings` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

```bash,run
cd /root/university-labs/bindings
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo3-StateVsBinding` for .NET, `demo3-state-vs-binding` for Python and Java. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo3-StateVsBinding* folder:

```bash,run
cd dotnet/Demo3-StateVsBinding
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo3-state-vs-binding* folder:

```bash,run
cd python/demo3-state-vs-binding
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo3-state-vs-binding* folder:

```bash,run
cd java/demo3-state-vs-binding
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Wait until the application is running before continuing. The Java application can take a little longer to start.
>
> Open the **Dev Dashboard** tab and check the application health on the **Applications** page: `engineering` is ready when the **Health** column shows a green dot. You can also inspect the output of the **Dapr CLI** window.

On the **Logs** page of the **Dev Dashboard** tab, select `engineering` and search for `wc-0001`. Each tick writes the reading twice. Your values will differ:

```text,nocopy
== APP - engineering == engineering warp-core scan wc-0001 stardate=85737.4 coreTempK=875 plasmaFlow=0.87
== APP - engineering == engineering saved reading wc-0001 to statestore (key=reading-wc-0001)
== APP - engineering == engineering stored reading wc-0001 in warp_core_readings
```

## 3. Read the reading back both ways

Use the **curl** window to read the first reading through the State API, by its key:

```bash,run
curl -s http://localhost:5201/state/wc-0001 | jq
```

Expected output. Your values will differ:

```json,nocopy
{
  "readingId": "wc-0001",
  "stardate": 85737.4,
  "coreTempK": 875,
  "plasmaFlow": 0.87
}
```

Now read the same reading through the binding. The app runs its own `SELECT`, and `jq` picks out `wc-0001`:

```bash,run
curl -s "http://localhost:5201/readings" | jq '.[] | select(.readingId == "wc-0001")'
```

Expected output, with the same values as above:

```json,nocopy
{
  "readingId": "wc-0001",
  "stardate": 85737.4,
  "coreTempK": 875,
  "plasmaFlow": 0.87,
  "recordedAt": "2026-11-19T09:25:19Z"
}
```

> [!NOTE]
> `/readings` returns the 20 newest readings, so after about three minutes `wc-0001` is no longer among them and the command prints nothing. Replace `wc-0001` with a newer reading ID, such as `wc-0015`, in both commands.

The same reading, stored twice. The binding's row has a `recordedAt` too, because the table has that column and the SQL selects it.

## 4. Compare the two tables

Use the **curl** window to look at the table the State API wrote to:

```bash,run
docker exec bindings-postgres psql -U dapr -d dapr -c "\d state"
```

Expected output:

```text,nocopy
                                      Table "public.state"
   Column   |           Type           | Collation | Nullable |             Default
------------+--------------------------+-----------+----------+----------------------------------
 key        | text                     |           | not null |
 value      | jsonb                    |           | not null |
 isbinary   | boolean                  |           | not null |
 insertdate | timestamp with time zone |           | not null | now()
 updatedate | timestamp with time zone |           |          |
 expiredate | timestamp with time zone |           |          |
 row_id     | bigint                   |           | not null | generated by default as identity
```

Dapr created this table on the first save. Now look at the table the binding wrote to:

```bash,run
docker exec bindings-postgres psql -U dapr -d dapr -c "\d warp_core_readings"
```

Its columns are `reading_id`, `stardate`, `core_temp_k`, `plasma_flow` and `recorded_at`: the schema in `bindings/sql/init.sql`, chosen by whoever wrote the app. Finally, look at two of the State API's rows:

```bash,run
docker exec bindings-postgres psql -U dapr -d dapr -c "SELECT key, value FROM state LIMIT 2;"
```

Expected output. Your values will differ:

```text,nocopy
             key              |                                        value
------------------------------+-------------------------------------------------------------------------------------
 engineering||reading-wc-0001 | {"stardate": 85737.4, "coreTempK": 875, "readingId": "wc-0001", "plasmaFlow": 0.87}
 engineering||reading-wc-0002 | {"stardate": 85737.4, "coreTempK": 902, "readingId": "wc-0002", "plasmaFlow": 0.95}
```

Dapr prefixed every key with the app ID, `engineering||`, so two apps with the same key don't overwrite each other. The value is the reading as a JSON document. Unlike `warp_core_readings`, the app doesn't clear this table at startup: a new run overwrites the keys.

## 5. When to use which

| | State API (`statestore`) | Binding (`ship-db`) |
|---|---|---|
| Who owns the table | Dapr: `state`, with a key, a JSON value and timestamps | You: your own schema |
| What you write | A key and a value | SQL |
| What you can do | Get, save and delete by key, with ETags for concurrency, TTL and transactions | Filter, sort and bulk-delete with any SQL |
| Portability | The same code works with 30+ stores: swap the component, keep the code | Tied to PostgreSQL: another database needs other SQL, or another binding |

Use the State API when you need key-value storage that stays portable: you can move from PostgreSQL to Redis or Cosmos DB by changing YAML. Use the binding when you need the full power of SQL and accept the tie to PostgreSQL. "All readings above 900 K" is one `WHERE` clause with the binding, and not something the State API does by key.

## 6. Stop the applications

Use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

---

One reading went into the same database twice: through the State API as a key and a JSON value in a table Dapr owns, and through the binding as a row in a table you designed.

## What's next?

In the last lab you'll combine bindings with another building block. A cron binding makes `engineering` call a second app, the subspace beacon, with service invocation, and the output binding logs every answer in the database.
