# Use the Dapr Pub/Sub API

The goal of this challenge is to run two Dapr applications using the Dapr CLI and understand how they communicate with each other asynchronously using pub/sub messaging that involves a message broker. You can choose between applications written in .NET, Python, Java or JavaScript.

## 1. Choose a language tab

Use one of the language tabs to navigate to one of the Pub/Sub examples. Each language tab contains two applications, located in `checkout` and `order-processor` subfolders, and a `dapr.yaml` file. The code you see in this challenge is available in the [Dapr QuickStarts](https://github.com/dapr/quickstarts/) repository. If you want to explore more code samples for other Dapr APIs in this repo, you can do so after completing this track.

## 2. Inspect the content of the `dapr.yaml` file:

 The `dapr.yaml` file is a Dapr Multi-App Run template file and contains information about the Dapr applications to run simultaneously using the Dapr CLI.

 For the .NET example the `dapr.yaml` is as follows:

```yaml,nocopy
version: 1
common:
  resourcesPath: ../../components/
apps:
  - appID: order-processor
    appDirPath: ./order-processor/
    appPort: 7006
    command: ["dotnet", "run"]
  - appID: checkout-sdk
    appDirPath: ./checkout/
    command: ["dotnet", "run"]
```

You'll see a `common` section with a `resourcesPath` that points to a `components` folder.  This folder contains the `pubsub.yaml` component file that specifies the message broker that will be used.

You'll also see two applications listed in the yaml file: `order-processor` and `checkout`. These are the respective *appIDs*, application identifiers, that Dapr requires. The `order-processor` application has an `appPort` assigned to it, this means that this is a service which can accept HTTP requests. The checkout application does not have an `appPort` and is therefore not a service, and its lifetime is limited to the execution time of the program (it's a console application).
The `command` part in the yaml file describes how to start the applications. This will be different for other languages and runtimes.

For more information on Multi-App Run, see the [Dapr Docs](https://docs.dapr.io/developing-applications/local-development/multi-app-dapr-run/multi-app-overview/).

## 3. Inspect the content of the `pubsub.yaml` file:

Use the *Components* tab and inspect the `pubsub.yaml` file.

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

Let's take a look at the `checkout` application. This application will publish messages to a topic on the message broker. Use the language tab of your choice to navigate to the `checkout` folder and select the code file that contains the application code.

- The `checkout` application is doing a `for` loop to send 10 messages to the message broker.
- The application uses the Dapr SDK to create a Dapr client, and the `PublishEvent`/`Publish` method on this client is used to publish an `Order`.
- The publish method takes the following arguments:
  - *Pub/Sub component name*: `orderpubsub`
  - *topic name*: `orders`
  - *payload*: `order`

## 5. Inspect the `order-processor` application

Now let's look at the `order-processor` application that receives the messages. Use the language tab of your choice to navigate to the `order-processor` folder and select the code file that contains the application code.

There are some differences between languages but all of them have an `/orders` endpoint that accepts POST requests with an `Order` payload. The code prints a `"Subscriber received"` message to the console and responds returns with a HTTP status code 200.

<details>
   <summary><b>.NET & Java specific</b></summary>

- For .NET & Java  you'll see a `Topic` attribute on the `/order` endpoint that contains the Pub/Sub component name, and the topic name.
- For .NET you'll also see two extension methods being used :
  - `app.UseCloudEvents();` this instructs the application that incoming messages are based on CloudEvents.
  - `app.MapSubscribeHandler();` this registers the `/dapr/subscribe` endpoint that is used by the Dapr runtime to subscribe to a topic.

</details>

<details>
   <summary><b>Python specific</b></summary>

For Python, there are two flavors of `order-processor` applications, one that uses Flask and one that uses FastApi:
- The Flask-based application, has  a `/dapr/subscribe` endpoint defined that the Dapr runtime uses to subscribe to the topic. The definition of this endoint contains the Pub/Sub component name and topic name, and a route, `/orders`, that will handle incoming messages.
- The FastApi-based application, contains a `DaprApp` with a `subscribe` route that contains the component name and topic.

</details>

<details>
   <summary><b>JavaScript specific</b></summary>

For JavaScript, a `DaprServer` type is instantiated. This type contains a `pubsub.subscribe()` method that contains arguments for the component name, topic, and callback function to handle the incoming message.

</details>

## 6. Run the applications

Now use the *Terminal* tab to run both `checkout` and `order-processor` applications using the Dapr CLI and the Multi-App Run file:

<details>
   <summary><b>Run the .NET apps</b></summary>

Install the dependencies and build the applications:

```bash,run
dotnet build csharp/sdk/checkout
dotnet build csharp/sdk/order-processor
```

Run the applications using the Dapr CLI:

```bash,run
dapr run -f "csharp/sdk/dapr.yaml"
```

</details>

<details>
   <summary><b>Run the Python apps</b></summary>

Create a virtual environment and activate it:

```bash,run
python3 -m venv venv
source venv/bin/activate
```

Install the dependencies:

```bash,run
pip3 install -r python/sdk/checkout/requirements.txt
pip3 install -r python/sdk/order-processor/requirements.txt
```

Run the applications using the Dapr CLI:

```bash,run
dapr run -f "python/sdk/dapr.yaml"
```

</details>

<details>
   <summary><b>Run the Java apps</b></summary>

Install the dependencies:

```bash,run
cd java/sdk/order-processor
mvn clean install
cd ../checkout
mvn clean install
```

Run the applications using the Dapr CLI:

```bash,run
cd ..
dapr run -f .
```

</details>

<details>
   <summary><b>Run the JavaScript apps</b></summary>

Install the dependencies:

```bash,run
cd javascript/sdk/order-processor
npm install
cd ../checkout
npm install
```

Run the applications using the Dapr CLI:

```bash,run
cd ..
dapr run -f .
```

</details>

## Expected output

Regardless of the language you use, the expected output should contain log statements from the `order-processor` and `checkout` apps:

```output
== APP - checkout-sdk == Published data: Order { OrderId = 1 }
== APP - order-processor == Subscriber received : Order { OrderId = 1 }
== APP - checkout-sdk == Published data: Order { OrderId = 2 }
== APP - order-processor == Subscriber received : Order { OrderId = 2 }
...
```

> [!NOTE]
> The application log statements of the subscriber can be earlier can the log statements of the publisher because communication between the applications is asynchronous.

## Summary

You've now successfully used the Dapr Pub/Sub API to send and receive messages using a message broker. The demos in this challenge use programmatic subscriptions, which are defined in the application code and implements a static subscription to one topic. There are other methods to subscribe to topics with Dapr. For more information read [Declarative, streaming and programmatic subscription types](https://docs.dapr.io/developing-applications/building-blocks/pubsub/subscription-methods/) in the Dapr Docs.

## Collect your badge & provide feedback

Congratulations! 🎉 You've now concluded the Dapr 101 training! Please take a moment to rate this training and provide feedback in the next step so we can keep improving this training 🚀.

Collect the Dapr University badge for this track by following [this link to the Holopin platform](https://holopin.io/collect/cmcnbdz1r295807jsdm16r929). You'll need a GitHub account to claim the badge.

[![Dapr University Dapr 101 badge](https://raw.githubusercontent.com/diagrid-labs/dapr-university-instruqt/refs/heads/main/dapr-101/5-pubsub-api/Diagrid-Dapr-Uni-101_x500.png)](https://holopin.io/collect/cmcnbdz1r295807jsdm16r929)

You can also join the [Dapr Discord](https://bit.ly/dapr-discord) where thousands of developers ask questions & share knowledge. You can use the **#university** channel on Discord for feedback or questions about the challenge.
