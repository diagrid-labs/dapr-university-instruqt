# Use the Dapr Service Invocation API

The goal of this challenge is to run two Dapr applications using the Dapr CLI and understand how they communicate with each other using service invocation. You can choose between applications written in .NET, Python, Java or JavaScript.

## 1. Choose a language tab

Use one of the language tabs to navigate to one of the Service Invocation examples. Each language tab contains two applications, located in `checkout` and `order-processor` subfolders, and a `dapr.yaml` file. The code you see in this challenge is available in the [Dapr QuickStarts](https://github.com/dapr/quickstarts/) repository. If you want to explore more code samples for other Dapr APIs in this repo, you can do so after completing this track.

## 2. Inspect the content of the `dapr.yaml` file:

 The `dapr.yaml` file is a Dapr Multi-App Run template file and contains information about the Dapr applications to run simultaneously using the Dapr CLI.

 For the .NET example the `dapr.yaml` is as follows:

```bash
version: 1
apps:
  - appDirPath: ./order-processor/
    appID: order-processor
    appPort: 7001
    command: ["dotnet", "run"]
  - appID: checkout
    appDirPath: ./checkout/
    command: ["dotnet", "run"]
```

You'll see two applications listed in the yaml file: `order-processor` and `checkout`. These are the respective *appIDs*, application identifiers, that Dapr requires. The `order-processor` application has an `appPort` assigned to it, this means that this is a service which can accept HTTP requests. The checkout application does not have an `appPort` and is therefore not a service, and its lifetime is limited to the execution time of the program (it's a console application).
The `command` part in the yaml file describes how to start the applications. This will be different for other languages and runtimes.

For more information on Multi-App Run, see the [Dapr Docs](https://docs.dapr.io/developing-applications/local-development/multi-app-dapr-run/multi-app-overview/).

## 3. Inspect the `checkout` application

Let's take a look at the `checkout` application that will make an HTTP request to the other service. Use the language tab of your choice to navigate to the `checkout` folder and select the code file that contains the application code.

- The `checkout` application is doing a `for` loop to send 20 requests to the `order-processor` application.
- You will see that the application constructs a Dapr URL. This is always `localhost` since Dapr runs in a process next to your application. You will also see the `dapr-app-id` header being set. For the .NET example this is configured as the `appID` parameter when creating an `HttpClient` via the `DaprClient`.
- The `dapr-app-id` header is set to `order-processor` and this instructs Dapr where to send the request to. Dapr uses a name resolution component for service discovery that is based on Dapr application IDs, there is no need to use IP addresses.  When running in self-hosted mode, Dapr name resolution is based on mDNS by default.
- Finally, when the POST request is made, the `/order` endpoint, that exists in the `order-processor` application is added to the URL.

## 4. Inspect the `order-processor` application

Now let's look at the `order-processor` service that contains the `/order` endpoint. Use the language tab of your choice to navigate to the `order-processor` folder and select the code file that contains the application code.

Here, you will see a definition of the `/order` endpoint that accepts POST requests with an `Order` payload. The code prints an `"Order received"` message to the console and returns a HTTP status code 200.

## 5. Run the applications

Now use the *Terminal* tab to run both `checkout` and `order-processor` applications using the Dapr CLI and the Multi-App Run file:

<details>
   <summary><b>Run the .NET apps</b></summary>

	Install the depedencies:

```bash
dotnet restore csharp/http/checkout
dotnet restore csharp/http/order-processor
```

Run the applications using the Dapr CLI:

```bash
dapr run -f "csharp/http/dapr.yaml"
```
</details>

<details>
   <summary><b>Run the Python apps</b></summary>

Create a virtual environment and activate it:

```bash
python3 -m venv venv
source venv/bin/activate
```

Install the depedencies:

```bash
pip3 install -r python/http/checkout/requirements.txt
pip3 install -r python/http/order-processor/requirements.txt
```

Run the applications using the Dapr CLI:

```bash
dapr run -f "python/http/dapr.yaml"
```
</details>

<details>
   <summary><b>Run the Java apps</b></summary>

Install the depedencies:

```bash
cd java/http/order-processor
mvn clean install
cd ../checkout
mvn clean install
```

Run the applications using the Dapr CLI:

```bash
cd ..
dapr run -f .
```
</details>

<details>
   <summary><b>Run the JavaScript apps</b></summary>

Install the dependencies:

```bash
cd javascript/http/order-processor
npm install
cd ../checkout
npm install
```
Run the applications using the Dapr CLI:

```bash
cd ..
dapr run -f .
```
</details>

## Expected output

Reagardless of the language you use, the expected output should contain log statements from the `order-processor` and `checkout` apps:

```output
== APP - order-processor == Order received : Order { orderId = 1 }
== APP - checkout == Order passed: Order { OrderId = 1 }
== APP - order-processor == Order received : Order { orderId = 2 }
== APP - checkout == Order passed: Order { OrderId = 2 }
== APP - order-processor == Order received : Order { orderId = 3 }
== APP - checkout == Order passed: Order { OrderId = 3 }
...
```

## Summary
You've now successfully used the Dapr Service Invocation API to communicate between two applications. The application that is sending the request is using the **Dapr appID** to identify the target Dapr application. The format of the URL is **`{DAPR_HOST}:{DAPR_HTTP_PORT}/{METHOD}`**. The demos in this challenge used this URL: `http://localhost:3500/orders`. Let's try another frequently used Dapr API in the next challenge.
