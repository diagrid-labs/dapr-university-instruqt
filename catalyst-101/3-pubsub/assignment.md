Catalyst comes with a built-in pub/sub service that you can use in your Dapr applications. In this challenge, you'll run two Dapr applications that communicate via this built-in message broker.

## 1. View the Diagrid Pub/Sub service

1. Use the **Catalyst** tab and navigate to the *Diagrid Services* menu item in the left sidebar. Expand the menu item to show list of services.
2. Select the *Diagrid Pub/Sub* service to view the details of the service.
3. Select the *pubsub* name to drill down into the Pub/Sub service details. Currently there are no Dapr Pub/Sub components or topics configured. But this will change once you run the applications in the next steps.

## 2. Explore the Pub/Sub applications

Choose one of the language tabs to explore the code. For each language, there are two applications:

- *publisher*: This application publishes messages to a topic using Dapr's pub/sub API.
- *subscriber*: This application subscribes to the topic and processes the messages. 

Both applications use a *pubsub.yaml* component file that specifies that Redis is used as the message broker. The *subscriber* application uses a declarative subscription, this means the definition of the subscription is configured in a *yaml* file.

> [!IMPORTANT]
> When you use Catalyst and the Diagrid CLI to run the Dapr applications, you don't need to have Dapr running locally, nor do you need to have a Redis instance running since Catalyst provides the message broker.

Each demo in this challenge has a Dapr Multi-App run file (*dev-language-pubsub.yaml*) that contains the configuration of which applications to run and which Dapr component files to use. This yaml file will be used by the Diagrid CLI in the next step to run the applications and to provision the Catalyst resources in case they don't exist yet. In this case, the CLI will create a Catalyst project, inspect the component *pubsub.yaml* and *subscription.yaml* files, and create a pub/sub component, a topic, and a subscription in Catalyst. The CLI will also create a Catalyst *App ID* for each application. *App IDs* are representations of the applications that you're running locally in this sandbox environment.

## 3. Run the Dapr Pub/Sub applications

Now run the applications using the Diagrid CLI. Choose one of the instructions below to run the applications in that language.

<details>
   <summary><b>Run the .NET apps</b></summary>

1. Select the **Terminal** tab and run the following command to navigate to the .NET apps:

```bash,run
cd csharp
```

2. Install the dependencies:

```bash,run
dotnet restore publisher/publisher.csproj
dotnet restore subscriber/subscriber.csproj
```

3. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-csharp-pubsub.yaml --project catalyst-demo --approve
```

3. You'll be asked to deploy to the project you just created. Select `Y` and `Enter` to proceed.
4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "publisher" to ...` and `Connected App ID "subscriber" to ...` in the **Terminal** tab logs before you continue.

6. Select the **curl** tab, and run the following command to make a `POST` request to the `order` endpoint of the `publisher` application:

```bash,run
curl -X POST -H "Content-Type: application/json" -d '{ "orderId": 1 }' http://localhost:5001/order
```

The expected output should contain the ID and a message.

</details>

<details>
   <summary><b>Run the Java apps</b></summary>

1. Select the **Terminal** tab and run the following command to navigate to the Java apps:

```bash,run
cd java
```

2. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-java-pubsub.yaml --project catalyst-demo --approve
```

3. You'll be asked to deploy to the project you just created. Select `Y` and `Enter` to proceed.
4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "publisher" to ...` and `Connected App ID "subscriber" to ...` in the **Terminal** tab logs before you continue.

6. Select the **curl** tab, and run the following command to make a `POST` request to the `order` endpoint of the `publisher` application:

```bash,run
curl -X POST -H "Content-Type: application/json" -d '{ "orderId": 1 }' http://localhost:5001/order
```

The expected output should contain the ID and a message.

</details>

<details>
   <summary><b>Run the Python apps</b></summary>

1. Select the **Terminal** tab and run the following command to navigate to the Python apps:

```bash,run
cd python
```

2. Create and activate a virtual environment:

```bash,run
uv venv --allow-existing
source .venv/bin/activate
```

3. Install the dependencies:

```bash,run
uv pip install -r publisher/requirements.txt
uv pip install -r subscriber/requirements.txt
```

4. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-python-pubsub.yaml --project catalyst-demo --approve
```

3. You'll be asked to deploy to the project you just created. Select `Y` and `Enter` to proceed.
4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "publisher" to ...` and `Connected App ID "subscriber" to ...` in the **Terminal** tab logs before you continue.

6. Select the **curl** tab, and run the following command to make a `POST` request to the `order` endpoint of the `publisher` application:

```bash,run
curl -X POST -H "Content-Type: application/json" -d '{ "orderId": 1 }' http://localhost:5001/order
```

The expected output should contain the ID and a message.

</details>

<details>
   <summary><b>Run the JavaScript apps</b></summary>

1. Select the **Terminal** tab and run the following command to navigate to the JavaScript apps:

```bash,run
cd javascript
```

2. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-javascript-pubsub.yaml --project catalyst-demo --approve
```

3. You'll be asked to deploy to the project you just created. Select `Y` and `Enter` to proceed.
4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "publisher" to ...` and `Connected App ID "subscriber" to ...` in the **Terminal** tab logs before you continue.

6. Select the **curl** tab, and run the following command to make a `POST` request to the `order` endpoint of the `publisher` application:

```bash,run
curl -X POST -H "Content-Type: application/json" -d '{ "orderId": 1 }' http://localhost:5001/order
```

The expected output should contain the ID and a message.

</details>

## 4. View the Diagrid Pub/Sub service

1. Go back to the **Catalyst** tab and navigate to the *Diagrid Services* menu in the left sidebar. Locate the *pubsub* service again and drill down into the details.
2. Now, you'll see that there is a `pubsub` component configured and the *Topic Explorer* contains details about the topic the applications are using to publish and subscribe to.

## 5. Inspect the Call Graph

Catalyst provides a call graph that shows how the applications interact with each other and with other services such as message brokers and state stores.

1. Use the **Catalyst** tab and navigate to the *Call Graph* menu in the left sidebar.
2. You should the a graph that contains two nodes, one for the *publisher* application and one for the *subscriber* application. The arrow between the two applications indicates the direction of communication.
3. Click on the *publisher* node and select *Isolate*. The graph changes and will now also show the Pub/Sub service. In addition the arrow to and from the Pub/Sub service contain an icon where metrics can be viewed.

> [!NOTE]
> You need to publish a couple of messages in order for metrics to be shown in the call graph.

Select the **Terminal** tab and stop the running applications by pressing `Ctrl+C`.

---

Now that you have used the built-in Pub/Sub service in Catalyst let's continue with the next challenge where you'll learn how to use the built-in Key-Value store in Catalyst.