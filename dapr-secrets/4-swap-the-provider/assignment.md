In this challenge, you'll swap the secret store from a local file to HashiCorp Vault, and run the same application against it. This hands-on challenge takes about 7 minutes to complete.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

## 1. One name, another store

The application asks Dapr for a secret store called `secretstore`. It has never known, and never will know, what is behind that name. So to swap the provider you don't touch the application. You change the YAML that defines `secretstore`.

Use the **Editor** tab and open the `Demo3-SwapProvider` folder of your language (for example `dotnet/Demo3-SwapProvider`). It holds only configuration:

- `dapr.yaml`: open it. `appDirPath` is `../Demo1-ReadSecret`, the very same application you used in challenges 1 and 2. It is not a copy. `resourcesPath` points to the `resources` folder next to it, which is the only difference with the `dapr.yaml` of `Demo1-ReadSecret`.
- `resources/secretstore-vault.yaml`: the new `secretstore`.
- `resources/statestore-with-secretref.yaml`: the state store component from challenge 2, which takes its password from `secretstore`. You'll see what happens to it in step 5.

> [!NOTE]
> `secretstore-vault.yaml` is in a folder of its own because a Dapr sidecar refuses to start when two components have the same name. Next to `secretstore-local.yaml` it would be a second `secretstore`.

## 2. Compare the two components

Open `secretstore-vault.yaml` in `resources` and compare it with `secretstore-local.yaml` in the `resources` folder of your language (for example `dotnet/resources`):

```yaml
metadata:
  name: secretstore
spec:
  type: secretstores.hashicorp.vault
  version: v1
  metadata:
  - name: vaultAddr
    value: http://localhost:8200
  - name: vaultToken
    value: root
```

- `metadata.name` is still `secretstore`. That's why the application does not change.
- `type` is now `secretstores.hashicorp.vault`. Only the implementation behind the name is different.
- `vaultAddr` and `vaultToken` replace `secretsFile`. The sandbox runs Vault in a container in dev mode, where the root token is `root`. Never put a token in a file like this for a real Vault.

The sandbox already stored your secrets in Vault, under the names Dapr expects (`secret/dapr/orderdb-password`, and so on). That is the work of the sandbox, not of the application. `legacy-api-key` is still not in the store, as in challenge 3.

## 3. Run the same application against Vault

> [!IMPORTANT]
> Run `dapr run -f .` from inside the `Demo3-SwapProvider` folder. If an application from an earlier challenge is still running, stop it first with `Ctrl+C` in the **Dapr CLI** window.

> [!NOTE]
> Expand the language-specific instructions to start the application. The application is already built, so there is nothing you need to rebuild.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo3-SwapProvider* folder:

```bash,run
cd dotnet/Demo3-SwapProvider
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Python</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/Demo3-SwapProvider* folder:

```bash,run
cd python/Demo3-SwapProvider
```

Run the application using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Java</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/Demo3-SwapProvider* folder:

```bash,run
cd java/Demo3-SwapProvider
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
> The application can start accepting requests a moment before its Dapr sidecar is ready. If the first `curl` in the next step returns an error with status 500 (`UNAVAILABLE`), that is not a failure of the swap. Wait a few seconds and run it again.

The **Dapr CLI** window should show a line like this when the sidecar is started. The port number can differ, and your application's logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "order-api". HTTP Port: 3500. gRPC Port: 39945
```

## 4. Ask for the secret, and find out where it came from

Use the **curl** window. This is the same request as in challenge 1:

```bash,run
curl -s http://localhost:5001/secret/orderdb-password
```

Expected output:

```text,nocopy
{"name":"orderdb-password","value":"s3cr3t-pa55w0rd"}
```

Same application, same request, same answer. Now ask the sidecar which type of component `secretstore` is:

```bash,run
curl -s http://localhost:3500/v1.0/metadata | grep -o '"name":"secretstore","type":"[^"]*"'
```

Expected output:

```text,nocopy
"name":"secretstore","type":"secretstores.hashicorp.vault"
```

The password came from Vault. You can prove it by adding a secret that only Vault has. It is not in `secrets.json`. This command stores a secret named `shipping-token` in Vault:

```bash,run
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=root vault vault kv put secret/dapr/shipping-token shipping-token=from-vault
```

The application reads it right away:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5001/secret/shipping-token
```

Expected output:

```text,nocopy
{"name":"shipping-token","value":"from-vault"} 200
```

The error contract did not change either. Ask for the secret that is in no store:

```bash,run
curl -s -w ' %{http_code}\n' http://localhost:5001/secret/legacy-api-key
```

Expected output:

```text,nocopy
{"name":"legacy-api-key","error":"INTERNAL"} 500
```

A secret that does not exist is a 500, just as it was with the local file.

## 5. The state store follows

In challenge 2, the state store component got its password from `secretstore` through a `secretKeyRef`. That component is in the folder too, and it did not change. Its reference is now answered by Vault. Use the **curl** window to save and read a value:

```bash,run
curl -s -X POST -H "Content-Type: application/json" -d '[{"key":"order-1","value":"queued"}]' http://localhost:3500/v1.0/state/statestore
```

```bash,run
curl -s http://localhost:3500/v1.0/state/statestore/order-1
```

Expected output:

```text,nocopy
"queued"
```

Components that use `secretKeyRef` don't know which secret store provider is behind the name either.

## 6. Check your work and stop

Click the *Check* button while the application is still running: the check asks it. When it passes, use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

---

You ran the same application against a different `secretstore` YAML, and it read its secrets from Vault instead of a file. The application was already built, and no source file in `Demo1-ReadSecret` changed. That is what the Secrets API gives you: your code asks for a secret by name, and where it lives is a decision for the platform.

Here is what you did in this track:

1. **What is the Secrets API:** you read a secret through your application instead of keeping it in code or config.
2. **The component and its parameters:** you configured the local file store, read secrets one by one and in bulk, and let a state store get its password with `secretKeyRef`.
3. **Secret scoping:** you ran two identical apps and saw Dapr refuse one of them, with a 403 for a secret it may not read and a 500 for one that is not there.
4. **Swap the provider:** you ran the same application with a `secretstore` that points at HashiCorp Vault, and saw that the only thing that differs in what the application reads its secrets through is the `secretstore` component file.

## Feedback and further learning

Congratulations! 🎉 You've completed the Dapr University secrets learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving this training 🚀.

We have more opportunities for you to learn and share knowledge:

**Try another university track**
- [Dapr 101: State Management, Service Invocation, and Pub/Sub](https://www.diagrid.io/university/dapr-101)
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)

**Read more**
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).
- Read the [Secrets management overview](https://docs.dapr.io/developing-applications/building-blocks/secrets/secrets-overview/) and [How to: use secret scoping](https://docs.dapr.io/operations/configuration/secret-scope/) in the Dapr Docs.

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#agents* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.
