In this challenge, you'll find out what each field of a secret store component does, and read secrets one at a time and in bulk. You'll also see a second component get its password from the secret store instead of having it written in its own file. This hands-on challenge takes about 8 minutes to complete.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

## 1. The component, field by field

Use the **Editor** tab and open the `secretstore-local.yaml` file in the `resources` folder of your language (for example `dotnet/resources`). Every field in it has a job, and each one is something you could change:

- `metadata.name: secretstore` is the name callers use. The application passes `secretstore` to the Secrets API, and it is the part of the URL in `/v1.0/secrets/secretstore/...`. Rename the component and every caller, in code and in URLs, has to change with it.
- `type: secretstores.local.file` selects the implementation. Everything the application does stays the same when you change this to a different type, such as HashiCorp Vault. Only where the secrets come from changes. You'll do exactly that later in this track.
- `secretsFile` is the one setting this store cannot work without: the JSON file to read. Point it at another file and the application sees other secrets. Point it at a file that does not exist and the sidecar refuses to start: it logs a fatal error for the `secretstore` component that ends in the operating system's `open <your file>: no such file or directory`, and exits, because a component that cannot initialize is treated as a failure, not as an empty store.

Two more optional fields of this component are not in the file, so they have their defaults. Both are about secrets that are nested inside the JSON file instead of flat:

- `nestedSeparator` (default `:`) is the text placed between the parts of a nested secret's name.
- `multiValued` (default `false`) decides whether a nested secret is flattened into many names, or kept together under one name.

You'll try both in step 6.

## 2. Run the application

The `dapr.yaml` file in the demo folder points the sidecar at the `resources` folder, so every component file in that folder is loaded.

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder (`Demo1-ReadSecret` of your language). The `secretsFile` path in the component is relative to that folder.

> [!NOTE]
> Expand the language-specific instructions to start the application.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo1-ReadSecret* folder:

```bash,run
cd dotnet/Demo1-ReadSecret
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/Demo1-ReadSecret* folder:

```bash,run
cd python/Demo1-ReadSecret
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/Demo1-ReadSecret* folder:

```bash,run
cd java/Demo1-ReadSecret
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Inspect the output of the **Dapr CLI** window. Wait until the application is running before continuing. The Java application can take a little longer to start.

> [!NOTE]
> The application can start accepting requests a moment before its Dapr sidecar is ready. If the first `curl` in the next step returns an error, wait a few seconds and run it again.

The **Dapr CLI** window should show these lines when the sidecar is started. The port number can differ, and your own application's logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "order-api". HTTP Port: 3500. gRPC Port: 39945
ℹ️  Writing log files to directory : .../Demo1-ReadSecret/.dapr/logs
```

The second line matters later in this challenge: with `dapr run -f .` the sidecar's own log goes to that folder, not to the window.

Use the **curl** window to read a single secret, as in the previous challenge:

```bash,run
curl -s http://localhost:5001/secret/orderdb-password
```

Expected output:

```text,nocopy
{"name":"orderdb-password","value":"s3cr3t-pa55w0rd"}
```

## 3. Read all secrets at once

The application has a second endpoint, `GET /secrets`, that asks Dapr for every secret in the store with one call.

> [!NOTE]
> Expand the language-specific instructions to inspect the endpoint.

<details>
   <summary><b>.NET</b></summary>

Open the `Program.cs` file in the `dotnet/Demo1-ReadSecret` folder. The `/secrets` endpoint calls `daprClient.GetBulkSecretAsync("secretstore")`.

</details>

<details>
   <summary><b>Python</b></summary>

Open the `app.py` file in the `python/Demo1-ReadSecret` folder. The `/secrets` endpoint calls `client.get_bulk_secret(store_name="secretstore")`.

</details>

<details>
   <summary><b>Java</b></summary>

Open the `SecretController.java` file in the `java/Demo1-ReadSecret/src/main/java/io/diagrid/university/secrets` folder. The `/secrets` endpoint calls `daprClient.getBulkSecret("secretstore")`.

</details>

###

Call it from the **curl** window:

```bash,run
curl -s http://localhost:5001/secrets
```

Expected output:

```text,nocopy
{"orderdb-password":"s3cr3t-pa55w0rd","payments-api-key":"pk-test-7f3a9"}
```

Both secrets in the store come back. Now ask the sidecar directly:

```bash,run
curl -s http://localhost:3500/v1.0/secrets/secretstore/bulk
```

Expected output:

```text,nocopy
{"orderdb-password":{"orderdb-password":"s3cr3t-pa55w0rd"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
```

Look at the shape. Dapr returns every secret as a map of its own, because a single secret can hold several fields (you'll see that with `multiValued` in step 6). The application flattened that into one simple object before answering you.

## 4. A component that gets its password from the secret store

Open the `statestore-with-secretref.yaml` file in the same `resources` folder. It defines a Redis state store named `statestore`, and the sidecar loaded it together with the secret store. A Redis password is normally written into the component like this:

```yaml
- name: redisPassword
  value: s3cr3t-pa55w0rd
```

That puts the password in a file that is committed next to the code. This component does something different:

```yaml
- name: redisPassword
  secretKeyRef:
    name: orderdb-password
    key: orderdb-password
auth:
  secretStore: secretstore
```

- `secretKeyRef` replaces `value`. It says: do not use a literal, look this one up. `name` is the secret and `key` is the field inside it. For the local file store they are the same.
- `auth.secretStore` says which component to look it up in: the `secretstore` component from step 1.

The sidecar does the lookup while it loads the state store, so the password is in `secrets.json` and nowhere else. First check that the state store works. Save a value:

```bash,run
curl -s -X POST -H "Content-Type: application/json" -d '[{"key":"order-1","value":"queued"}]' http://localhost:3500/v1.0/state/statestore
```

This command prints nothing when it succeeds. Now read it back:

```bash,run
curl -s http://localhost:3500/v1.0/state/statestore/order-1
```

Expected output:

```text,nocopy
"queued"
```

> [!NOTE]
> That does not prove the password came from the secret store. The Redis container that `dapr init` started has no password, so it accepts requests with or without one. To see the lookup happen you need the sidecar's own log.

### Watch the lookup happen

The sidecar log is not shown in the **Dapr CLI** window. `dapr run -f .` writes it to the `.dapr/logs` folder inside the demo folder, which is the folder named on the *Writing log files* line you saw earlier. Each time you start the application you get a new `order-api_daprd_*.log` file there.

Use the **curl** window to go to your demo folder:

<details>
   <summary><b>.NET</b></summary>

```bash,run
cd dotnet/Demo1-ReadSecret
```

</details>

<details>
   <summary><b>Python</b></summary>

```bash,run
cd python/Demo1-ReadSecret
```

</details>

<details>
   <summary><b>Java</b></summary>

```bash,run
cd java/Demo1-ReadSecret
```

</details>

###

Search the sidecar logs for the line that says the state store was loaded:

```bash,run
grep -h "Component loaded: statestore" .dapr/logs/order-api_daprd_*.log
```

Expected output, one line for every time you started the application from this folder (the timestamp and instance name differ):

```text,nocopy
time="2026-10-21T10:15:02.123456789Z" level=info msg="Component loaded: statestore (state.redis/v1)" app_id=order-api ...
```

### Break the reference

Now make the reference point at a secret that does not exist.

1. In the **Editor** tab, open `statestore-with-secretref.yaml` in your language's `resources` folder and change `name: orderdb-password` to `name: not-in-the-store`. Leave `key` alone.
2. In the **Dapr CLI** window, press `Ctrl+C`, then start the application again from the same folder and wait a few seconds:

```bash,run
dapr run -f .
```

Search the logs for the failed lookup:

```bash,run
grep -h "Error getting secret" .dapr/logs/order-api_daprd_*.log
```

Expected output:

```text,nocopy
time="2026-10-21T10:21:40.123456789Z" level=error msg="Error getting secret: secret not-in-the-store not found" app_id=order-api ...
```

Look at what did not happen: the sidecar did not stop. It logged the error and loaded the state store without a password, and the application still started. A component that cannot resolve its reference fails quietly, so this log line is the only place you will see it.

Change `name` back to `orderdb-password` in the **Editor** before you continue.

## 5. Stop the application

Use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

## 6. Try nestedSeparator and multiValued

The `nested-demo` folder holds a secrets file with a nested secret, `orderdb`, that has two fields: `user` and `password`. Open `nested-demo/resources/nested-stores.yaml`. It has three secret stores that read that same file. They differ only in the two fields from step 1.

Use the **Dapr CLI** window to go to the folder and start a sidecar without an application:

```bash,run
cd ../../nested-demo
```

```bash,run
dapr run --app-id nested-demo --dapr-http-port 3500 --resources-path resources
```

The **Dapr CLI** window should show this message when the sidecar is up:

```text,nocopy
✅  You're up and running! Dapr logs will appear here.
```

First the store with the defaults. Use the **curl** window:

```bash,run
curl -s http://localhost:3500/v1.0/secrets/nested-default/bulk
```

Expected output:

```text,nocopy
{"orderdb:password":{"orderdb:password":"demo-nested-password"},"orderdb:user":{"orderdb:user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
```

The nested `orderdb` secret became two flat secrets, and `:` joins the parts of the name. Now the store with `nestedSeparator` set to `.`:

```bash,run
curl -s http://localhost:3500/v1.0/secrets/nested-flat/bulk
```

Expected output:

```text,nocopy
{"orderdb.password":{"orderdb.password":"demo-nested-password"},"orderdb.user":{"orderdb.user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
```

Same secrets, different names. An application that asks for `orderdb:password` gets nothing from this store, so the separator is part of the contract between the component and its callers. Finally the store with `multiValued` set to `true`:

```bash,run
curl -s http://localhost:3500/v1.0/secrets/nested-multi/bulk
```

Expected output:

```text,nocopy
{"orderdb":{"password":"demo-nested-password","user":"orders"},"payments-api-key":{"payments-api-key":"pk-test-7f3a9"}}
```

Nothing is flattened. `orderdb` is one secret with two fields, which is the reason Dapr wraps every secret in a map. Ask for it by name:

```bash,run
curl -s http://localhost:3500/v1.0/secrets/nested-multi/orderdb
```

Expected output:

```text,nocopy
{"password":"demo-nested-password","user":"orders"}
```

One request returns the whole database login. Use the **Dapr CLI** window to stop the sidecar by pressing `Ctrl+C`.

---

You now know what each part of a secret store component does. Let's move on to *secret scoping*, where you decide which application may read which secret.
