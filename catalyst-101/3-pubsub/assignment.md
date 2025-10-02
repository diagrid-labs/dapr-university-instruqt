Catalyst comes with a built-in pub/sub service that you can use in your Dapr applications. In this challenge you'll run two Dapr applications that communicate via this built-in message broker.

## 1. View the Diagrid Pub/Sub service

// TODO

## 2. Explore the Pub/Sub applications

Choose one of the language tabs to explore the code. For each language, there are two applications:

- *publisher*: This application publishes messages to a topic using Dapr's pub/sub API.
- subscriber*: This application subscribes to the topic and processes the messages. The subscriber application uses a declarative subscription, this means the definition of the subscription is configured in a *yaml* file.

## 3. Run the Dapr Pub/Sub applications

<details>
   <summary><b>Run the .NET apps</b></summary>

1. Use the **Terminal** tab to navigate to the .NET apps:

```bash,run
cd csharp
```

2. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-csharp-pubsub.yaml
```

3. Wait until the the two applications are connected to Catalyst.
4. In the **curl** tab, run the following command to make a `POST` request to the `order` endpoint of the `publisher` application:

```bash,run
```

</details>

<details>
   <summary><b>Run the Java apps</b></summary>

1. Use the **Terminal** tab to navigate to the Java apps:

```bash,run
cd java
```

2. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-java-pubsub.yaml
```

3. Wait until the the two applications are connected to Catalyst.
4. In the **curl** tab, run the following command to make a `POST` request to the `order` endpoint of the `publisher` application:

```bash,run
```

</details>

<details>
   <summary><b>Run the Python apps</b></summary>

1. Use the **Terminal** tab to navigate to the Python apps:

```bash,run
cd python
```

2. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-python-pubsub.yaml
```

3. Wait until the the two applications are connected to Catalyst.
4. In the **curl** tab, run the following command to make a `POST` request to the `order` endpoint of the `publisher` application:

```bash,run
```

</details>

<details>
   <summary><b>Run the JavaScript apps</b></summary>

1. Use the **Terminal** tab to navigate to the JavaScript apps:

```bash,run
cd javascript
```

2. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-javascript-pubsub.yaml
```

3. Wait until the the two applications are connected to Catalyst.
4. In the **curl** tab, run the following command to make a `POST` request to the `order` endpoint of the `publisher` application:

```bash,run
```
</details>