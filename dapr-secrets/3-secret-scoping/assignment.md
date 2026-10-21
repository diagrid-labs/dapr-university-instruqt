In this challenge, you'll run two apps that have the same code and read from the same secret store. One of them reads a secret. The other asks for the same secret and is told no. This hands-on challenge takes about 8 minutes to complete.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

## 1. Two apps, one store

Use the **Editor** tab and open the `Demo2-Scoping` folder of your language (for example `dotnet/Demo2-Scoping`). It holds:

- `AppA` and `AppB`: two apps with exactly the same code. Each has one endpoint, `GET /secret/{name}`, that asks the `secretstore` component for a secret. App A listens on 5002 and App B on 5003, and even that comes from `dapr.yaml`, not from the code.
- `resources`: the `secretstore` component you know from the previous challenges, and a file named `config-app-b.yaml` that you'll meet in step 4.
- `dapr.yaml`: starts both apps, each with its own Dapr sidecar. Open it. App A's sidecar listens on port 3501 and App B's on 3502.

Nothing in the code of either app says which secrets it may read. Remember that, because the refusal is coming and the code will not be where it comes from.

## 2. Run both apps

> [!IMPORTANT]
> Run `dapr run -f .` from inside the `Demo2-Scoping` folder. The `secretsFile` path in the component is relative to the app folders inside it. If an app from an earlier challenge is still running, stop it first with `Ctrl+C` in the **Dapr CLI** window.

> [!NOTE]
> Expand the language-specific instructions to start the applications.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo2-Scoping* folder:

```bash,run
cd dotnet/Demo2-Scoping
```

Run both applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/Demo2-Scoping* folder:

```bash,run
cd python/Demo2-Scoping
```

Run both applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/Demo2-Scoping* folder:

```bash,run
cd java/Demo2-Scoping
```

Run both applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Inspect the output of the **Dapr CLI** window. Wait until both applications are running before continuing. The Java applications can take a little longer to start.

> [!NOTE]
> An application can start accepting requests a moment before its Dapr sidecar is ready. If the first `curl` in the next step returns an error, wait a few seconds and run it again.

The **Dapr CLI** window should show these lines when the sidecars have started. The port numbers can differ, and your applications' logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "app-a". HTTP Port: 3501. gRPC Port: 35935
ℹ️  Started Dapr with app id "app-b". HTTP Port: 3502. gRPC Port: 39745
```

## 3. Both apps read the secret

Use the **curl** window. The `-w` option adds the HTTP status after the response body. Ask App A for the database password:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5002/secret/orderdb-password
```

Expected output:

```text,nocopy
{"name":"orderdb-password","value":"s3cr3t-pa55w0rd"} 200
```

Now ask App B for the very same secret:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5003/secret/orderdb-password
```

Expected output:

```text,nocopy
{"name":"orderdb-password","value":"s3cr3t-pa55w0rd"} 200
```

Both apps got the password. That is not a bug in App B. Nothing has told Dapr that App B should be treated differently, so the secret store answers anyone who asks.

## 4. Tell App B no

Open `config-app-b.yaml` in the `resources` folder of `Demo2-Scoping`. It is a Dapr `Configuration` resource, not a component. A component says what Dapr can talk to. A configuration says how one sidecar behaves.

```yaml
spec:
  secrets:
    scopes:
      - storeName: secretstore
        defaultAccess: deny
        allowedSecrets: ["payments-api-key", "legacy-api-key"]
```

- `storeName` is the secret store the rule is about.
- `defaultAccess: deny` means that every secret in that store is off limits for this sidecar...
- ...except the ones in `allowedSecrets`. App B may read `payments-api-key` and `legacy-api-key`, and nothing else. `orderdb-password` is not on the list.

The file does nothing yet, because no sidecar has been told to use it. Open `dapr.yaml` in the `Demo2-Scoping` folder. Under `app-b`, the line that starts with `# configFilePath:` is commented out. Delete the `# ` at the start of that line (the hash and the space after it) so that it reads:

```yaml
    configFilePath: ../resources/config-app-b.yaml
```

Only `app-b` has this line, so the rule applies to App B's sidecar and to nothing else. Save the file.

A sidecar reads its configuration when it starts, so restart the applications. Use the **Dapr CLI** window: press `Ctrl+C`, wait for the applications to stop, and then run:

```bash,run
dapr run -f .
```

Wait until the two `Started Dapr` lines appear again. If you ask too early, you get an error with status 500 (`UNAVAILABLE`) because the sidecar is not ready yet. That is not the refusal. Wait a few seconds and ask again.

## 5. The refusal

Ask App B for the database password again, with the same command as before. Use the **curl** window:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5003/secret/orderdb-password
```

Expected output:

```text,nocopy
{"name":"orderdb-password","error":"PERMISSION_DENIED"} 403
```

App B was told no. Now ask App A, which has no configuration, for the same secret:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5002/secret/orderdb-password
```

Expected output:

```text,nocopy
{"name":"orderdb-password","value":"s3cr3t-pa55w0rd"} 200
```

Same secret, same store, same code. App A gets the password and App B gets a 403, and the only difference between them is one line in `dapr.yaml`.

The app did not make that decision. Ask App B's sidecar directly, bypassing the app:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:3502/v1.0/secrets/secretstore/orderdb-password
```

Expected output:

```text,nocopy
{"errorCode":"ERR_PERMISSION_DENIED","message":"access denied by policy to get \"orderdb-password\" from \"secretstore\""} 403
```

The sidecar refused before the secret store was even asked. Notice the two spellings. Dapr says `ERR_PERMISSION_DENIED`. The app shows `PERMISSION_DENIED` because it reports the failure in its own words: it passes the refusal on instead of hiding it.

## 6. Denied is not the same as missing

App B is allowed to read `payments-api-key`:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5003/secret/payments-api-key
```

Expected output:

```text,nocopy
{"name":"payments-api-key","value":"pk-test-7f3a9"} 200
```

The configuration also allows `legacy-api-key`, but the secret store has no secret with that name:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5003/secret/legacy-api-key
```

Expected output:

```text,nocopy
{"name":"legacy-api-key","error":"INTERNAL"} 500
```

This is a different failure: status 500, not 403. Dapr let the request through and the store had nothing to give. There are two kinds of no: `403` means you may not read this, and `500` means you may, and there is nothing there.

A 403 does not mean the secret exists, though. Ask App B for a secret that is not in the store and is not on the allowed list either:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5003/secret/does-not-exist
```

Expected output:

```text,nocopy
{"name":"does-not-exist","error":"PERMISSION_DENIED"} 403
```

It gets the same refusal as the real `orderdb-password`. Dapr checks the scoping rules before it looks in the store, so a refusal says nothing about whether the secret exists. An app that is scoped out cannot use the refusals to find out which secrets are there.

## 7. The other direction

You can also write the rule the other way around: allow everything, and name what is forbidden. Open `config-app-b.yaml` again and make two changes. Change `defaultAccess: deny` to `defaultAccess: allow`, and replace the whole `allowedSecrets` line with this line:

```yaml,copy
        deniedSecrets: ["orderdb-password"]
```

Save the file. Use the **Dapr CLI** window: press `Ctrl+C`, wait for the applications to stop, and then run:

```bash,run
dapr run -f .
```

When the two `Started Dapr` lines appear again (and a `curl` that returns 500 `UNAVAILABLE` only means the sidecar is not ready yet), ask App B for the two secrets in the **curl** window:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5003/secret/orderdb-password
```

Expected output:

```text,nocopy
{"name":"orderdb-password","error":"PERMISSION_DENIED"} 403
```

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5003/secret/payments-api-key
```

Expected output:

```text,nocopy
{"name":"payments-api-key","value":"pk-test-7f3a9"} 200
```

The result is the same, but the thinking is reversed. With an allow list, a secret that someone adds to the store later is off limits until you list it. With a deny list, it is open until you list it. For secrets, the allow list is usually the safer choice.

## 8. Check your work and stop

Click the *Check* button while both applications are still running: the check asks them. When it passes, use the **Dapr CLI** window to stop the applications by pressing `Ctrl+C`.

---

An app can now only read the secrets it is allowed to read. Let's move on to *swapping the secret store*, where the secrets move to HashiCorp Vault and the apps do not change.
