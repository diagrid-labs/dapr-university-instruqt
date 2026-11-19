# Use the Service Invocation API

The goal of this lab is to run two Dapr applications using the Dapr CLI and understand how they communicate with each other using service invocation. You can choose between applications written in .NET, Python, Java or JavaScript. This hands-on lab takes about 5 minutes to complete.

## Before you start

The terminals, and the applications running in them, stay as they are when you move between labs. The Dapr sidecar from the previous lab, `myapp`, may still be running in the **Dapr CLI** window if you skipped the stop step in the previous lab, and it holds port 3500. Open the **Dev Dashboard** tab and look at the **Applications** page. If `myapp` is listed, use the **Dapr CLI** window to stop it by pressing `Ctrl+C`. Then go back to the **Editor** tab.

## 1. Choose a language

Use the **Editor** tab and open the service invocation demo folder of your language: `dapr-101/dotnet/ServiceInvocation`, `dapr-101/python/service-invocation`, `dapr-101/java/service-invocation` or `dapr-101/javascript/service-invocation`. Each folder contains two applications, located in the `checkout` and `order-processor` subfolders, and a `dapr.yaml` file.

## 2. Inspect the content of the `dapr.yaml` file

In the previous lab, you started a single sidecar from a Multi-App Run template. The `dapr.yaml` file in this folder is a template too, but this one starts two applications, each with its own sidecar.

For the .NET example the `dapr.yaml` is as follows:

```yaml,nocopy
version: 1
apps:
  - appID: order-processor
    appDirPath: ./order-processor/
    appPort: 7001
    command: ["dotnet", "run"]
  - appID: checkout
    appDirPath: ./checkout/
    command: ["dotnet", "run"]
```

Compared to the template of the previous lab:

- There are two entries under `apps`, with the app IDs `order-processor` and `checkout`. The Dapr CLI starts both, each with a sidecar.
- Each entry has an `appDirPath` that points to the folder of that application, so each application writes its logs to its own `.dapr/logs` folder.
- Each entry has a `command`, which starts the application. It differs per language and runtime: `dotnet run` for .NET, for example.
- The `order-processor` entry has an `appPort`: the port the application listens on. Its sidecar forwards incoming requests to that port, so `order-processor` is a service that accepts HTTP requests. The `checkout` application has no `appPort`. It is not a service, but a console application that runs until its work is done.
- There is no `daprHTTPPort`, so the Dapr CLI picks a free HTTP port for each sidecar. Each application gets the port of its own sidecar from the `DAPR_HTTP_PORT` environment variable.

## 3. Inspect the `checkout` application

Let's take a look at the `checkout` application that will make an HTTP request to the other service. In the **Editor** tab, open the `checkout` folder of your language and select the code file that contains the application code: `Program.cs` for .NET, `app.py` for Python, `CheckoutServiceApplication.java` for Java (in `src/main/java/com/service`) or `index.js` for JavaScript.

- The `checkout` application is doing a `for` loop to send 20 requests to the `order-processor` application (19 in the Python version).
- You will see that the application constructs a Dapr URL. This is always `localhost` since Dapr runs in a process next to your application. You will also see the `dapr-app-id` header being set. For the .NET example this is configured as the `appID` parameter when creating an `HttpClient` via the `DaprClient`.
- The `dapr-app-id` header is set to `order-processor` and this instructs Dapr where to send the request to. Dapr uses a name resolution component for service discovery that is based on Dapr application IDs, there is no need to use IP addresses.  When running in self-hosted mode, Dapr name resolution is based on mDNS by default.
- Finally, when the POST request is made, the `/orders` endpoint, that exists in the `order-processor` application is added to the URL.

## 4. Inspect the `order-processor` application

Now let's look at the `order-processor` service that contains the `/orders` endpoint. In the **Editor** tab, open the `order-processor` folder of your language and select the code file that contains the application code: `Program.cs` for .NET, `app.py` for Python, `OrderProcessingServiceController.java` for Java (in `src/main/java/com/service/controller`) or `index.js` for JavaScript.

Here, you will see a definition of the `/orders` endpoint that accepts POST requests with an `Order` payload. The code prints an `"Order received"` message to the console and returns a HTTP status code 200.

## 5. Run the applications

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `dapr-101` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

```bash,run
cd /root/ai-agent-tracks-instruqt/dapr-101
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `ServiceInvocation` for .NET, `service-invocation` for Python, Java and JavaScript. The `appDirPath` entries in `dapr.yaml` are relative to that folder.

> [!NOTE]
> When the apps start, the Editor shows a popup saying *Your application running on port `<number>` is available*. Close the popup, or click the settings gear to dismiss it. There is no UI to open, so don't click *Open in Browser*.

Then use the **Dapr CLI** window to run both the `checkout` and `order-processor` applications using the Dapr CLI and the Multi-App Run file:

<details>
   <summary><b>Run the .NET apps</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/ServiceInvocation* folder:

```bash,run
cd dotnet/ServiceInvocation
```

Run the applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the Python apps</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/service-invocation* folder:

```bash,run
cd python/service-invocation
```

Run the applications using the Dapr CLI:

```bash,run
uv run dapr run -f .
```

</details>

<details>
   <summary><b>Run the Java apps</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/service-invocation* folder:

```bash,run
cd java/service-invocation
```

The sandbox built the applications when it started. Run this to make sure the build is complete. It's quick when the build is already done:

```bash,run
cd order-processor
mvn -q -DskipTests install
cd ../checkout
mvn -q -DskipTests install
cd ..
```

Run the applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the JavaScript apps</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *javascript/service-invocation* folder:

```bash,run
cd javascript/service-invocation
```

The sandbox installed the dependencies when it started. Run this to make sure the install is complete. It's quick when the install is already done:

```bash,run
cd order-processor
npm install
cd ../checkout
npm install
cd ..
```

Run the applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Wait until both applications have started before continuing. The Java applications can take a little longer to start.
>
> Open the **Dev Dashboard** tab and check the application health on the **Applications** page: `order-processor` is ready when the **Health** column shows a green dot. `checkout` is a console application that stops after it has sent its requests, so its **Health** column shows `app down`. That is expected. You can also inspect the output of the **Dapr CLI** window.

The **Dapr CLI** window should show these lines when the sidecars have started. The port numbers can differ, and your applications' logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "order-processor". HTTP Port: 3510. gRPC Port: 35935
ℹ️  Started Dapr with app id "checkout". HTTP Port: 3511. gRPC Port: 39745
```

## 6. Read the logs

Regardless of the language you use, the logs should contain statements from the `order-processor` and `checkout` apps. `dapr run -f .` writes the log of every app and every sidecar to a file in the `.dapr/logs` folder of the app, and the **Dev Dashboard** reads those files for you:

1. Open the **Dev Dashboard** tab and go to the **Logs** page.
2. Select `order-processor` in the target drop-down. The `app` chip shows the application's own log and the `daprd` chip shows the log of its sidecar.
   Type `Order received` in the search bar to show only the lines that the `/orders` endpoint logged.
3. Then select `checkout` and look at its `app` log.

The lines below show only the message: in the real log, each language adds its own logger prefix after `== APP - <app> ==`, and the order is printed in the format of that language.

```text,nocopy
== APP - order-processor == Order received : Order { orderId = 1 }
== APP - checkout == Order passed: Order { OrderId = 1 }
== APP - order-processor == Order received : Order { orderId = 2 }
== APP - checkout == Order passed: Order { OrderId = 2 }
== APP - order-processor == Order received : Order { orderId = 3 }
== APP - checkout == Order passed: Order { OrderId = 3 }
...
```

## 7. Stop the applications

Use the **Dapr CLI** window to stop the applications by pressing `Ctrl+C`.

---

You've now successfully used the Dapr Service Invocation API to communicate between two applications. The application that is sending the request is using the **Dapr appID** to identify the target Dapr application. The format of the URL is **`{DAPR_HOST}:{DAPR_HTTP_PORT}/{METHOD}`**. The demos in this lab used URLs like `http://localhost:<DAPR_HTTP_PORT>/orders`, where the Dapr CLI sets `DAPR_HTTP_PORT` for each application.

## What's next?

Let's try another frequently used Dapr API in the next lab, the Pub/Sub API.
