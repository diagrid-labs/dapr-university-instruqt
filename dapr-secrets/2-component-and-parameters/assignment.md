# The component and its parameters

In this lab, you'll find out what each field of a secret store component does, and read secrets one at a time and in bulk. You'll also see a second component get its password from the secret store instead of having it written in its own file. This hands-on lab takes about 8 minutes to complete.

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

## 2. Check that the application is running

The `order-api` application from the previous lab should still be running in the **Dapr CLI** window. The `dapr.yaml` file in the demo folder points the sidecar at the `resources` folder, so every component file in that folder was loaded when the application started.

Open the **Dev Dashboard** tab and go to the **Applications** page. If `order-api` is listed there as running, go back to the **Editor** tab and continue with step 3.

### If the application is not running

If `order-api` is not on the **Applications** page, or the **Dapr CLI** window shows a prompt instead of application logs, start the application again.

Use the **Dapr CLI** window to go to the `secrets` folder first. The terminal stays in whatever folder it was in when you move between pages, so this makes sure the commands below start from the right place:

```bash,run
cd /root/ai-agent-tracks-instruqt/secrets
```

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

## 3. Read all secrets at once

The application has a second endpoint, `GET /secrets`, that asks Dapr for every secret in the store with one call.

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
curl -s http://localhost:5001/secrets | jq
```

Expected output:

```json,nocopy
{
  "orderdb-password": "s3cr3t-pa55w0rd",
  "payments-api-key": "pk-test-7f3a9"
}
```

Both secrets in the store come back. Now ask the sidecar directly:

```bash,run
curl -s http://localhost:3500/v1.0/secrets/secretstore/bulk | jq
```

Expected output:

```json,nocopy
{
  "orderdb-password": {
    "orderdb-password": "s3cr3t-pa55w0rd"
  },
  "payments-api-key": {
    "payments-api-key": "pk-test-7f3a9"
  }
}
```

Look at the shape. Dapr returns every secret as a map of its own, because a single secret can hold several fields (you'll see that with `multiValued` in step 6). The application flattened that into one simple object before answering you.

## 4. A component that gets its password from the secret store

Open the `statestore-with-secretref.yaml` file in the same `resources` folder. It defines a Redis state store named `statestore`, and the sidecar loaded it together with the secret store. A Redis password is normally written into the component like this:

```yaml,nocopy
- name: redisPassword
  value: s3cr3t-pa55w0rd
```

That puts the password in a file that is committed next to the code. This component does something different:

```yaml,nocopy
- name: redisPassword
  secretKeyRef:
    name: orderdb-password
    key: orderdb-password
auth:
  secretStore: secretstore
```

- `secretKeyRef` replaces `value`. It says: do not use a literal, look this one up. `name` is the secret and `key` is the field inside it. For the local file store they are the same.
- `auth.secretStore` says which component to look it up in: the `secretstore` component from step 1.

The sidecar does the lookup while it loads the state store, so the password is in `secrets.json` and nowhere else.

First check that the state store works. The command below uses the Dapr State Management API on the sidecar (port `3500`) to save a value in the `statestore` component. Use the **curl** window to save the value:

```bash,run
curl -s -X POST -H "Content-Type: application/json" -d '[{"key":"order-1","value":"queued"}]' http://localhost:3500/v1.0/state/statestore
```

This command prints nothing when it succeeds. Now look at what was saved. Open the **Dev Dashboard** tab and go to the **State** page. It lists the records in the state store: find the record with the key `order-1` and the app prefix `order-api`, and expand it to see its value, `queued`. Then go back to the **Editor** tab.

In this demo, the Redis container that `dapr init` started has no password, so it accepts requests with or without one.

## 5. Stop the application

Use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

## 6. Try nestedSeparator and multiValued

The `nested-demo` folder holds a secrets file with a nested secret, `orderdb`, that has two fields: `user` and `password`. Open `nested-demo/resources/nested-stores.yaml`. It has three secret store component definitions that read that same file. They differ only in the two fields from step 1.

Use the **Dapr CLI** window to go to the `secrets` folder and then to the `nested-demo` folder, and start a sidecar without an application:

```bash,run
cd /root/ai-agent-tracks-instruqt/secrets
```

```bash,run
cd nested-demo
```

```bash,run
dapr run --app-id nested-demo --dapr-http-port 3501 --resources-path resources
```

This sidecar listens on port `3501` instead of `3500`, so it does not clash with the `order-api` sidecar if that one is still running.

The **Dapr CLI** window should show this message when the sidecar is up:

```text,nocopy
✅  You're up and running! Dapr logs will appear here.
```

First the store with the defaults. Use the **curl** window:

```bash,run
curl -s http://localhost:3501/v1.0/secrets/nested-default/bulk | jq
```

Expected output:

```json,nocopy
{
  "orderdb:password": {
    "orderdb:password": "demo-nested-password"
  },
  "orderdb:user": {
    "orderdb:user": "orders"
  },
  "payments-api-key": {
    "payments-api-key": "pk-test-7f3a9"
  }
}
```

The nested `orderdb` secret became two flat secrets, and `:` joins the parts of the name. Now the store with `nestedSeparator` set to `.`:

```bash,run
curl -s http://localhost:3501/v1.0/secrets/nested-flat/bulk | jq
```

Expected output:

```json,nocopy
{
  "orderdb.password": {
    "orderdb.password": "demo-nested-password"
  },
  "orderdb.user": {
    "orderdb.user": "orders"
  },
  "payments-api-key": {
    "payments-api-key": "pk-test-7f3a9"
  }
}
```

Same secrets, different names. An application that asks for `orderdb:password` gets nothing from this store, so the separator is part of the contract between the component and its callers. Finally the store with `multiValued` set to `true`:

```bash,run
curl -s http://localhost:3501/v1.0/secrets/nested-multi/bulk | jq
```

Expected output:

```json,nocopy
{
  "orderdb": {
    "password": "demo-nested-password",
    "user": "orders"
  },
  "payments-api-key": {
    "payments-api-key": "pk-test-7f3a9"
  }
}
```

Nothing is flattened. `orderdb` is one secret with two fields, which is the reason Dapr wraps every secret in a map. Ask for it by name:

```bash,run
curl -s http://localhost:3501/v1.0/secrets/nested-multi/orderdb | jq
```

Expected output:

```json,nocopy
{
  "password": "demo-nested-password",
  "user": "orders"
}
```

One request returns the whole database login. Use the **Dapr CLI** window to stop the sidecar by pressing `Ctrl+C`.

## What's next?

So far every application with a sidecar can read every secret in the store. That is convenient, but it is also the problem: any application could read the payments key too.

In the next lab you'll run two applications with the same code against one secret store. Both read the database password at first. Then you'll give one of them a Dapr configuration that lists the secrets it may read, and see it refused with a 403, without changing any code.

---

You now know what each part of a secret store component does.
