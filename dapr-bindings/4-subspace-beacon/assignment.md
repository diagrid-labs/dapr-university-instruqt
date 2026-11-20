# Combining bindings with service invocation

In this final lab, you'll run two apps: a cron binding makes `engineering` call a subspace beacon with service invocation, and the output binding logs every answer in PostgreSQL. This hands-on lab takes about 7 minutes to complete.

## Before you start

Open the **Dev Dashboard** tab and check the **Applications** page. If an application from the previous lab is still running, use the **Dapr CLI** window to stop it by pressing `Ctrl+C`. This demo uses the same ports.

This demo needs the `bindings-postgres` database container. If `docker ps` in the **curl** window doesn't list it, start it again with the block in the section *If the database is not running* of the second lab.

## 1. Two apps, three building blocks

Use the **Editor** tab and open the demo folder of your language: `dotnet/Demo4-SubspaceBeacon`, `python/demo4-subspace-beacon` or `java/demo4-subspace-beacon`. It holds two apps, each with its own Dapr sidecar:

- `engineering` listens on port 5201, and its sidecar on 3520.
- `subspace-beacon` listens on port 5202, and its sidecar on 3521. It is a plain HTTP app with no Dapr SDK. It answers `GET /ping` with a signal that firms up on each call: 12, 27, 45, 63, 81, and then 94 from there on.

Open `beacon-ping.yaml` in the `resources` folder of the demo:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: beacon-ping
spec:
  type: bindings.cron
  version: v1
  metadata:
    - name: schedule
      value: "@every 5s"
    - name: direction
      value: "input"
scopes:
  - engineering
```

A cron binding again, every 5 seconds. `dapr run -f .` gives both sidecars the same `resources` folder, so without `scopes` the beacon's sidecar would load the binding too and call `POST /beacon-ping` on the beacon, which has no such endpoint. `scopes` limits the component to the app `engineering`.

Now open the `/beacon-ping` handler of `engineering`.

<details>
   <summary><b>.NET</b></summary>

Open `Program.cs` in the `dotnet/Demo4-SubspaceBeacon/Engineering` folder. The `/beacon-ping` endpoint uses an `HttpClient` made by `DaprClient.CreateInvokeHttpClient("subspace-beacon")` to call the beacon, inserts the answer into `comms_log` with the `exec` operation of `ship-db` (`ShipDb.cs`), and logs it.

</details>

<details>
   <summary><b>Python</b></summary>

Open `app.py` in the `python/demo4-subspace-beacon/engineering` folder. The `/beacon-ping` endpoint calls the beacon's `ping` method with `invoke_method` on the Dapr client, inserts the answer into `comms_log` with the `exec` operation of `ship-db`, and logs it.

</details>

<details>
   <summary><b>Java</b></summary>

Open `PingController.java` in the `java/demo4-subspace-beacon/engineering/src/main/java/io/diagrid/university/bindings/engineering` folder. The `/beacon-ping` endpoint calls the beacon with a Spring `RestClient` that `EngineeringApplication.java` points at its own sidecar with a `dapr-app-id: subspace-beacon` header, inserts the answer into `comms_log` with the `exec` operation of `ship-db` (`ShipDb.java`), and logs it.

</details>

Each tick runs three steps: an **input binding** triggers the handler, **service invocation** reaches the beacon by its app ID, and an **output binding** stores the answer. The code holds no host or port for the beacon and no connection to the database. Both sidecars find what they need from the app ID and the component names.

## 2. Run the demo

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `bindings` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

```bash,run
cd /root/university-labs/bindings
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `Demo4-SubspaceBeacon` for .NET, `demo4-subspace-beacon` for Python and Java. The `resourcesPaths` in `dapr.yaml` are relative to that folder.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo4-SubspaceBeacon* folder:

```bash,run
cd dotnet/Demo4-SubspaceBeacon
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/demo4-subspace-beacon* folder:

```bash,run
cd python/demo4-subspace-beacon
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/demo4-subspace-beacon* folder:

```bash,run
cd java/demo4-subspace-beacon
```

Run the two applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Wait until both applications are running before continuing. The Java applications can take a little longer to start.
>
> Open the **Dev Dashboard** tab and check the application health on the **Applications** page: `engineering` and `subspace-beacon` are ready when the **Health** column shows a green dot. You can also inspect the output of the **Dapr CLI** window.

The **Dapr CLI** window should show these lines when the sidecars have started. The gRPC ports can differ, and your applications' logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "engineering". HTTP Port: 3520. gRPC Port: 35935
ℹ️  Started Dapr with app id "subspace-beacon". HTTP Port: 3521. gRPC Port: 39745
```

## 3. Check where the binding is loaded

Use the **curl** window to ask the beacon's sidecar which components it loaded:

```bash,run
curl -s http://localhost:3521/v1.0/metadata | jq '.components'
```

Expected output:

```json,nocopy
[
  {
    "name": "ship-db",
    "type": "bindings.postgresql",
    "version": "v1",
    "capabilities": [
      "OUTPUT_BINDING"
    ]
  }
]
```

The beacon's sidecar loaded `ship-db`, which has no `scopes`, but not `beacon-ping`. Ask the sidecar of `engineering` the same:

```bash,run
curl -s http://localhost:3520/v1.0/metadata | jq '.components'
```

This list has both `ship-db` and `beacon-ping`, so only `engineering` gets the ticks.

## 4. Watch the channel open

On the **Logs** page of the **Dev Dashboard** tab, select `engineering` and search for `pinged`:

```text,nocopy
== APP - engineering == engineering pinged relay-theta-9 signalStrength=12 message="static"
== APP - engineering == engineering pinged relay-theta-9 signalStrength=27 message="static"
== APP - engineering == engineering pinged relay-theta-9 signalStrength=45 message="signal acquired"
== APP - engineering == engineering pinged relay-theta-9 signalStrength=63 message="signal acquired"
== APP - engineering == engineering pinged relay-theta-9 signalStrength=81 message="channel open"
== APP - engineering == engineering pinged relay-theta-9 signalStrength=94 message="channel open"
```

> [!NOTE]
> If the first line says `engineering beacon unreachable`, the beacon was still starting. The handler logs it, stores nothing and answers `200`: a cron tick is never retried, so an error status would change nothing. The next tick reaches the beacon.

Use the **curl** window to ask `engineering` how communications are going. It reads the last three pings from `comms_log` with a `query`:

```bash,run
curl -s http://localhost:5201/comms/status | jq
```

Right after startup the answer is:

```json,nocopy
{
  "status": "SEARCHING",
  "lastSignalStrength": 27
}
```

Run the command again after about 30 seconds. Once the last three pings all have a signal of 40 or more, the answer is:

```json,nocopy
{
  "status": "ESTABLISHED",
  "lastSignalStrength": 94
}
```

You can also call the beacon yourself, without Dapr, on its own port:

```bash,run
curl -s http://localhost:5202/ping | jq
```

Expected output. Your stardate will differ:

```json,nocopy
{
  "beaconId": "relay-theta-9",
  "signalStrength": 94,
  "message": "channel open",
  "stardate": 85737.5
}
```

A call of your own counts as a ping too, so if you call it early, the beacon's sequence moves on faster.

## 5. The pings in the database

Use the **curl** window to look at the pings `engineering` stored through the output binding:

```bash,run
docker exec bindings-postgres psql -U dapr -d dapr -c "SELECT * FROM comms_log;"
```

Expected output. The `id` keeps counting across runs, and your stardates and times will differ:

```text,nocopy
 id |   beacon_id   | signal_strength |     message     | stardate |           pinged_at
----+---------------+-----------------+-----------------+----------+-------------------------------
 25 | relay-theta-9 |              12 | static          |  85737.4 | 2026-11-19 09:26:50.091192+00
 26 | relay-theta-9 |              27 | static          |  85737.4 | 2026-11-19 09:26:55.014208+00
 27 | relay-theta-9 |              45 | signal acquired |  85737.4 | 2026-11-19 09:27:00.028696+00
 28 | relay-theta-9 |              63 | signal acquired |  85737.4 | 2026-11-19 09:27:05.021351+00
 29 | relay-theta-9 |              81 | channel open    |  85737.4 | 2026-11-19 09:27:10.018467+00
 30 | relay-theta-9 |              94 | channel open    |  85737.4 | 2026-11-19 09:27:15.024003+00
```

Every row is one tick of the input binding, one service invocation call and one `exec` of the output binding.

## 6. Stop the applications

Use the **Dapr CLI** window to stop the applications by pressing `Ctrl+C`.

---

A schedule, a call to another app and a database write ran together, each through its own Dapr building block. The code named a component and an app ID, and the sidecars did the rest.

Here is what you did in this track:

1. **Cron input binding:** Dapr called your app on a schedule, through a route named after the component, and you changed the schedule in YAML.
2. **PostgreSQL output binding:** the app stored, queried and purged rows with the `exec` and `query` operations, and read the query results by position.
3. **State API vs binding:** you saved each reading through both into the same database, compared the tables, and saw when to use which.
4. **Combining bindings with service invocation:** a cron tick made one app call another by app ID and store the answer through the output binding.

## Feedback and further learning

Congratulations! 🎉 You've completed the Dapr University bindings learning track!

### Next steps

We have more opportunities for you to learn and share knowledge:

**Learn more about bindings**
- Read the [Dapr bindings overview](https://docs.dapr.io/developing-applications/building-blocks/bindings/bindings-overview/), and the reference for the [cron binding](https://docs.dapr.io/reference/components-reference/supported-bindings/cron/) and the [PostgreSQL binding](https://docs.dapr.io/reference/components-reference/supported-bindings/postgresql/).
- The `ship-db` component holds its password in plain text. The Dapr Secrets track on [Dapr University](https://www.diagrid.io/university) shows how to read it from a secret store with `secretKeyRef`.

**Try another university track**
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Try these Dapr tools**
- [Dapr Dev Dashboard](https://docs.diagrid.io/dapr-open-source/dapr-dev-dashboard/), a free & OSS companion tool for local Dapr development.
- [Dapr Ops Dashboard](https://docs.diagrid.io/dapr-open-source/dapr-ops-dashboard/), a free SaaS solution that automates the operational management of Dapr on Kubernetes.

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#agents* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.

### Rate this track

Please rate this track so we can keep improving it 🚀. Then click **Finish & Exit** to finish the lab.

<instruqt-feedback id="dapr-bindings-feedback"></instruqt-feedback>

<instruqt-completion text="You've completed Dapr Bindings!"></instruqt-completion>
