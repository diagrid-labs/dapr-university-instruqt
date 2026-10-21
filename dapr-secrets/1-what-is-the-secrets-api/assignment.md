In this challenge, you'll run an application that reads a secret through the Dapr Secrets API. This hands-on challenge takes about 5 minutes to complete.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

## 1. Why a secret store?

The `order-api` application in this challenge needs a database password. It could read it from a config file or an environment variable, but then the password sits in plain text next to the code, in the deployment settings, and probably in a git history.

With the Dapr Secrets API the application only asks the Dapr sidecar for a secret *by name*. Where that secret really lives is configured in a Dapr component. In this challenge the component is the simplest one: a local file store that reads a `secrets.json` file.

The `secrets.json` file in the `secrets` folder contains two fake secrets: `orderdb-password` and `payments-api-key`.

## 2. Inspect the application

Use the **Editor** tab and open the demo for your language. Each language tab below contains the same application: an HTTP endpoint `GET /secret/{name}` that asks Dapr for the secret with that name and returns it.

> [!NOTE]
> Expand the language-specific instructions to inspect the application.

<details>
   <summary><b>.NET</b></summary>

Open the `Program.cs` file in the `dotnet/Demo1-ReadSecret` folder. The `/secret/{name}` endpoint calls `daprClient.GetSecretAsync("secretstore", name)`.

</details>

<details>
   <summary><b>Python</b></summary>

Open the `app.py` file in the `python/Demo1-ReadSecret` folder. The `/secret/{name}` endpoint calls `client.get_secret(store_name="secretstore", key=name)`.

</details>

<details>
   <summary><b>Java</b></summary>

Open the `SecretController.java` file in the `java/Demo1-ReadSecret/src/main/java/io/diagrid/university/secrets` folder. The `/secret/{name}` endpoint calls `daprClient.getSecret("secretstore", name)`.

</details>

Notice that the code only contains the name of the secret store, `secretstore`. There is no file path, no password and no connection string.

The secret store itself is defined in the `secretstore-local.yaml` file in the `resources` folder of your language (for example `dotnet/resources`). Open it and look at the `type` and the `secretsFile`. The component is named `secretstore`, which is how the application refers to it.

## 3. Run the application

The `dapr.yaml` file in the demo folder is a Multi-App Run file. It starts the `order-api` application together with its Dapr sidecar and tells Dapr where to find the components.

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder (`Demo1-ReadSecret` of your language). The `secretsFile` path in the component is relative to that folder, so running the command from anywhere else means the secret store cannot find `secrets.json`.

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
> The application can start accepting requests a moment before its Dapr sidecar is ready. If the first `curl` in the next step returns an error, that is not a problem with your setup: wait a few seconds and run it again.

The **Dapr CLI** window should show this message when everything is up:

```text,nocopy
✅  You're up and running! Both Dapr and your app logs will appear here.
```

## 4. Read a secret through the application

Use the **curl** window to ask the application for the `orderdb-password` secret:

```bash,run
curl -s http://localhost:5001/secret/orderdb-password
```

Expected output:

```text,nocopy
{"name":"orderdb-password","value":"s3cr3t-pa55w0rd"}
```

Now ask for the other secret in the file:

```bash,run
curl -s http://localhost:5001/secret/payments-api-key
```

Expected output:

```text,nocopy
{"name":"payments-api-key","value":"pk-test-7f3a9"}
```

## 5. Read a secret from the Dapr API directly

The application did not read `secrets.json` itself. It called the Dapr Secrets API of its sidecar, and you can do the same with curl. The sidecar listens on port 3500 and the `secretstore` component is part of the URL:

```bash,run
curl -s http://localhost:3500/v1.0/secrets/secretstore/orderdb-password
```

Expected output:

```text,nocopy
{"orderdb-password":"s3cr3t-pa55w0rd"}
```

This is the same API in every language, and it is the same API no matter which secret store sits behind the `secretstore` component.

## 6. Stop the application

Use the **Dapr CLI** window to stop the application by pressing `Ctrl+C`.

## What's next?

Right now there is one application and it can read every secret in the store. That is convenient, but it is also the problem: any application with a sidecar could read the payments key too.

Later in this track a second application joins `order-api`. Both applications read their secrets without trouble at first, and by the end of the track you'll make the second one fail on purpose.

---

You've now read a secret through the Dapr Secrets API. Let's move on to the *secret store component* and how it can be configured.
