# Use the Pub/Sub API

In this final lab, you'll run two Dapr applications using the Dapr CLI and see how they communicate with each other asynchronously, using pub/sub messaging with a message broker. You can choose between applications written in .NET, Python, Java or JavaScript. This hands-on lab takes about 6 minutes to complete. At the end of the lab, you can claim the Dapr University Holopin badge for this track.

## Before you start

The terminals, and the applications running in them, stay as they are when you move between labs. Open the **Dev Dashboard** tab and look at the **Applications** page. If the applications from the previous labs, `order-processor` and `checkout` (lab 4) or `myapp` (lab 3), are still listed, use the **Dapr CLI** window to stop them by pressing `Ctrl+C`. Then go back to the **Editor** tab.

## 1. Choose a language

Use the **Editor** tab and open the pub/sub demo folder of your language: `dapr-101/dotnet/PubSub`, `dapr-101/python/pub-sub`, `dapr-101/java/pub-sub` or `dapr-101/javascript/pub-sub`. Each folder contains two applications, located in the `checkout` and `order-processor` subfolders, a `resources` folder and a `dapr.yaml` file. For Python, the `checkout` folder is a publisher and the `order-processor` is a Flask application.

## 2. Inspect the content of the `dapr.yaml` file

The `dapr.yaml` file is a Dapr Multi-App Run template file and contains information about the Dapr applications to run simultaneously using the Dapr CLI.

For the .NET example the `dapr.yaml` is as follows:

```yaml,nocopy
version: 1
common:
  resourcesPaths: ["./resources"]
apps:
  - appID: order-processor-sdk
    appDirPath: ./order-processor/
    appPort: 7006
    command: ["dotnet", "run"]
  - appID: checkout-sdk
    appDirPath: ./checkout/
    command: ["dotnet", "run"]
```

You'll see a `common` section with a `resourcesPaths` entry that points to the `resources` folder. This folder contains the `pubsub.yaml` component file that specifies the message broker that will be used.

You'll also see two applications listed in the yaml file: `order-processor-sdk` and `checkout-sdk`. These are the respective *appIDs*, application identifiers, that Dapr requires. The `order-processor-sdk` application has an `appPort` assigned to it, this means that this is a service which can accept HTTP requests. The `checkout-sdk` application does not have an `appPort` and is therefore not a service, and its lifetime is limited to the execution time of the program (it's a console application).
The `command` part in the yaml file describes how to start the applications. This will be different for other languages and runtimes.

For more information on Multi-App Run, see the [Dapr Docs](https://docs.dapr.io/developing-applications/local-development/multi-app-dapr-run/multi-app-overview/).

## 3. Inspect the content of the `pubsub.yaml` file

In the **Editor** tab, open the `resources` folder of your demo and select the `pubsub.yaml` file.

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: orderpubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
```

The value of the `metadata.name` attribute is `orderpubsub`. This component name will be present in the application code as well. You'll see this in the next section. The component type is `pubsub.redis`, this means that Redis Streams is used as the message broker.
The `spec.metadata` contains connection details, in this case, Dapr connects to the default Redis instance that is installed during the initialization of Dapr in self-hosted mode.

## 4. Inspect the `checkout` application

Let's take a look at the `checkout` application. This application will publish messages to a topic on the message broker. In the **Editor** tab, open the `checkout` folder of your language and select the code file that contains the application code.

- The `checkout` application is doing a `for` loop to send 10 messages to the message broker.
- The application uses the Dapr SDK to create a Dapr client, and the `PublishEvent`/`Publish` method on this client is used to publish an `Order`.
- The publish method takes the following arguments:
  - *Pub/Sub component name*: `orderpubsub`
  - *topic name*: `orders`
  - *payload*: `order`

## 5. Inspect the `order-processor` application

Now let's look at the `order-processor` application that receives the messages. In the **Editor** tab, open the `order-processor` folder of your language and select the code file that contains the application code.

There are some differences between languages but all of them have an `/orders` endpoint that accepts POST requests with an `Order` payload. The code prints a `"Subscriber received"` message to the console and returns a HTTP status code 200.

<details>
   <summary><b>.NET & Java specific</b></summary>

- For .NET & Java you'll see a `Topic` attribute on the `/orders` endpoint that contains the Pub/Sub component name, and the topic name.
- For .NET you'll also see two extension methods being used:
  - `app.UseCloudEvents();` this instructs the application that incoming messages are based on CloudEvents.
  - `app.MapSubscribeHandler();` this registers the `/dapr/subscribe` endpoint that is used by the Dapr runtime to subscribe to a topic.

</details>

<details>
   <summary><b>Python specific</b></summary>

The Python `order-processor` is a Flask application. It has a `/dapr/subscribe` endpoint defined that the Dapr runtime uses to subscribe to the topic. The definition of this endpoint contains the Pub/Sub component name and topic name, and a route, `/orders`, that will handle incoming messages.

</details>

<details>
   <summary><b>JavaScript specific</b></summary>

For JavaScript, a `DaprServer` type is instantiated. This type contains a `pubsub.subscribe()` method that contains arguments for the component name, topic, and callback function to handle the incoming message.

</details>

## 6. Run the applications

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Dapr CLI** window to go to the `dapr-101` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

```bash,run
cd /root/ai-agent-tracks-instruqt/dapr-101
```

> [!IMPORTANT]
> Run `dapr run -f .` from inside the demo folder of your language: `PubSub` for .NET, `pub-sub` for Python, Java and JavaScript. The `appDirPath` entries in `dapr.yaml` are relative to that folder.

> [!NOTE]
> When the apps start, the Editor shows a popup saying *Your application running on port `<number>` is available*. Close the popup, or click the settings gear to dismiss it. There is no UI to open, so don't click *Open in Browser*.

Then use the **Dapr CLI** window to run both the `checkout` and `order-processor` applications using the Dapr CLI and the Multi-App Run file:

<details>
   <summary><b>Run the .NET apps</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/PubSub* folder:

```bash,run
cd dotnet/PubSub
```

Build the applications:

```bash,run
dotnet build checkout
dotnet build order-processor
```

Run the applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the Python apps</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/pub-sub* folder:

```bash,run
cd python/pub-sub
```

Install the dependencies:

```bash,run
uv sync --all-packages
```

Run the applications using the Dapr CLI:

```bash,run
uv run dapr run -f .
```

</details>

<details>
   <summary><b>Run the Java apps</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *java/pub-sub* folder:

```bash,run
cd java/pub-sub
```

Build the applications:

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

Navigate to the *javascript/pub-sub* folder:

```bash,run
cd javascript/pub-sub
```

Install the dependencies:

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
> Wait until both applications are running before continuing. The Java applications can take a little longer to start.
>
> Open the **Dev Dashboard** tab and check the application health on the **Applications** page: `order-processor-sdk` and `checkout-sdk` are ready when the **Health** column shows a green dot. You can also inspect the output of the **Dapr CLI** window.

The **Dapr CLI** window should show these lines when the sidecars have started. The port numbers can differ, and your applications' logs follow:

```text,nocopy
ℹ️  Started Dapr with app id "order-processor-sdk". HTTP Port: 3510. gRPC Port: 35935
ℹ️  Started Dapr with app id "checkout-sdk". HTTP Port: 3511. gRPC Port: 39745
```

> [!NOTE]
> The application log statements of the subscriber can be earlier than the log statements of the publisher because communication between the applications is asynchronous.

## 7. Read the logs

Regardless of the language you use, the logs should contain statements from the `order-processor-sdk` and `checkout-sdk` apps. `dapr run -f .` writes the log of every app and every sidecar to a file in the `.dapr/logs` folder of the app, and the **Dev Dashboard** reads those files for you:

1. Open the **Dev Dashboard** tab and go to the **Logs** page.
2. Select `checkout-sdk` in the target drop-down and look at its `app` log.
3. Then select `order-processor-sdk` and look at its `app` log. The `daprd` chip shows the log of its sidecar.

The lines below show only the message: in the real log, each language adds its own logger prefix after `== APP - <app> ==`, and the order is printed in the format of that language.

```text,nocopy
== APP - checkout-sdk == Published data: Order { OrderId = 1 }
== APP - order-processor-sdk == Subscriber received : Order { OrderId = 1 }
== APP - checkout-sdk == Published data: Order { OrderId = 2 }
== APP - order-processor-sdk == Subscriber received : Order { OrderId = 2 }
...
```

## 8. Inspect the subscription

The `order-processor-sdk` application told its sidecar which topic to subscribe to, and the **Dev Dashboard** shows what the sidecar knows about it.

1. Open the **Dev Dashboard** tab and go to the **Subscriptions** page.
2. Find the row of `order-processor-sdk`. It shows the pub/sub component `orderpubsub` and the topic `orders`, the route that handles the messages and the type of the subscription. The demos in this lab use programmatic subscriptions, which are defined in the application code.

## 9. Publish a message from the dashboard

You can publish a message to the topic yourself, without writing any code:

1. On the **Subscriptions** page, use the publish action on the `orders` row. This opens the Publish dialog.
2. Enter this value in the **Payload** field and leave the **Content-Type** as it is:

   ```json,nocopy
   {"orderId": 100}
   ```

3. Click **Publish**.
4. Go to the **Logs** page, select `order-processor-sdk` and look at its `app` log. You should find a `Subscriber received` line for order 100.

The dialog also has a *Show advanced* section with options such as `ttlInSeconds` and `rawPayload`.

## 10. Stop the applications

Use the **Dapr CLI** window to stop the applications by pressing `Ctrl+C`.

---

You've now successfully used the Dapr Pub/Sub API to send and receive messages using a message broker. The demos in this lab use programmatic subscriptions, which are defined in the application code and implement a static subscription to one topic. There are other methods to subscribe to topics with Dapr. For more information read [Declarative, streaming and programmatic subscription types](https://docs.dapr.io/developing-applications/building-blocks/pubsub/subscription-methods/) in the Dapr Docs.

Here is what you did in this track:

1. **What is Dapr?:** you learned what Dapr is and how its building blocks fit together.
2. **The Dapr CLI:** you checked the preinstalled Dapr CLI and the result of `dapr init`.
3. **State management:** you saved and read state with the State Management API and inspected it on the Dev Dashboard.
4. **Service invocation:** you ran two applications where `checkout` calls `order-processor` through its Dapr appID.
5. **Pub/Sub:** you published messages to a topic and received them in a subscriber, and published one from the Dev Dashboard.

## Collect your badge & provide feedback

Congratulations! 🎉 You've completed the Dapr 101 training! Click **Finish & Exit** below to finish the lab 🚀.

Collect the Dapr University badge for this track by following [this link to the Holopin platform](https://holopin.io/collect/cmcnbdz1r295807jsdm16r929). You'll need a GitHub account to claim the badge.

[![Dapr University Dapr 101 badge](https://raw.githubusercontent.com/diagrid-labs/dapr-university-instruqt/refs/heads/main/dapr-101/5-pubsub-api/Diagrid-Dapr-Uni-101_x500.png)](https://holopin.io/collect/cmcnbdz1r295807jsdm16r929)

## Next steps

We have more opportunities for you to learn and share knowledge:

**Try another university track**
- [Dapr Workflow: durable execution for reliable distributed applications](https://www.diagrid.io/university/dapr-workflow)
- [Dapr Pub/Sub: subscription types, CloudEvents, bulk messages and more](https://www.diagrid.io/university/pubsub)

**Read more**
- Read the [State of Dapr 2026 report](https://www.diagrid.io/reports-and-ebooks/state-of-dapr-2026).
- Read [Understanding Dapr Pub/Sub Subscription Types](https://www.diagrid.io/blog/understanding-dapr-pub-sub-subscription-types-declarative-programmatic-streaming).

**Join the community**
- Join the [Dapr Discord](https://diagrid.ws/dapr-discord) where thousands of developers share knowledge about Dapr. There are dedicated *#workflow*, *#agents* and language channels.
- Register for one of [our webinars](https://www.diagrid.io/webinars) to learn more about building reliable applications.

<instruqt-completion text="You've completed Dapr 101!"></instruqt-completion>
