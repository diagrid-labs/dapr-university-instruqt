Catalyst comes with a built-in key value (KV) store that you can use in your Dapr applications. In this challenge, you'll run a Dapr application that uses the state management API to interact with this KV Store.

## 1. Explore the State Management application

Choose one of the language tabs to explore the code. For each language, there is one application that uses the Dapr state management API to store, retrieve, and delete key value pairs.

The application uses a *statestore.yaml* component file that specifies Redis is used as the KV Store.

> [!IMPORTANT]
> When you use Catalyst and the Diagrid CLI to run the Dapr applications, you don't need to have Dapr running locally, nor do you need to have a Redis instance running since Catalyst provides the KV state store.

Each demo in this challenge has a Dapr Multi-App run file (*dev-language-state.yaml*) that contains the configuration of which applications to run and which Dapr component files to use. This yaml file will be used by the Diagrid CLI in the next step to run the applications and to provision the Catalyst resources in case they don't exist yet. In this case, Catalyst will inspect the component *statestore.yaml* file, and create a *kvstore* component in Catalyst to use the built-in KV Store service.

## 2. Run the Dapr State Management applications

Now run the applications using the Diagrid CLI. Choose one of the instructions below to run the applications in that language.

<details>
   <summary><b>Run the .NET apps</b></summary>

1. Use the **Terminal** tab and run the following command to navigate to the .NET apps:

   ```bash,run
   cd csharp
   ```

2. Install the dependencies:

   ```bash,run
   dotnet restore
   ```

3. Use the Diagrid CLI to run the applications using the Multi-App Run file:

   ```bash,run
   diagrid dev run -f dev-csharp-state.yaml --project catalyst-demo --approve
   ```

4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "order-app" to ...` in the **Terminal** tab logs before you continue.

6. Use the **curl** tab, and run the following command to make a `POST` request to the `order` endpoint of the `order-app` application:

   ```bash,run
   curl -X POST -H "Content-Type: application/json" -d '{ "orderId": 4 }' http://localhost:5001/order
   ```

   The expected output should contains the ID and a message.

   A new KV pair has been created in the Catalyst KV Store. You can verify this in the last step of this challenge.

7. To retrieve the new KV pair, Use the **curl** tab again, and run the following command to make a `GET` request to the `order/{orderId}` endpoint of the `order-app` application:

   ```bash,run
   curl http://localhost:5001/order/4
   ```

   The expected output should look like this:

   ```json,nocopy
   {"data": {"orderId":4}}
   ```

</details>

<details>
   <summary><b>Run the Java apps</b></summary>

1. Use the **Terminal** tab to navigate to the Java apps:

   ```bash,run
   cd java
   ```

2. Install the dependencies:

   ```bash,run
   mvn install
   ```

3. Use the Diagrid CLI to run the applications using the Multi-App Run file:

   ```bash,run
   diagrid dev run -f dev-java-state.yaml --project catalyst-demo --approve
   ```

4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "order-app" to ...` in the **Terminal** tab logs before you continue.

6. Use the **curl** tab, and run the following command to make a `POST` request to the `order` endpoint of the `order-app` application:

   ```bash,run
   curl -X POST -H "Content-Type: application/json" -d '{ "orderId": 4 }' http://localhost:5001/order
   ```

   The expected output should contains the ID and a message.

   A new KV pair has been created in the Catalyst KV Store. You can verify this in the last step of this challenge.

7. To retrieve the new KV pair, Use the **curl** tab again, and run the following command to make a `GET` request to the `order/{orderId}` endpoint of the `order-app` application:

   ```bash,run
   curl http://localhost:5001/order/4
   ```

   The expected output should look like this:

   ```json,nocopy
   {"data": {"orderId":4}}
   ```

</details>

<details>
   <summary><b>Run the Python apps</b></summary>

1. Use the **Terminal** tab to navigate to the Python apps:

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
   uv pip install -r requirements.txt
   ```

4. Use the Diagrid CLI to run the applications using the Multi-App Run file:

   ```bash,run
   diagrid dev run -f dev-python-state.yaml --project catalyst-demo --approve
   ```

5. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
6. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "order-app" to ...` in the **Terminal** tab logs before you continue.

7. Use the **curl** tab, and run the following command to make a `POST` request to the `order` endpoint of the `order-app` application:

   ```bash,run
   curl -X POST -H "Content-Type: application/json" -d '{ "orderId": 4 }' http://localhost:5001/order
   ```

   The expected output should contains the ID and a message.

   A new KV pair has been created in the Catalyst KV Store. You can verify this in the last step of this challenge.

8. To retrieve the new KV pair, Use the **curl** tab again, and run the following command to make a `GET` request to the `order/{orderId}` endpoint of the `order-app` application:

   ```bash,run
   curl http://localhost:5001/order/4
   ```

   The expected output should look like this:

   ```json,nocopy
   {"data": {"orderId":4}}
   ```

</details>

<details>
   <summary><b>Run the JavaScript apps</b></summary>

1. Use the **Terminal** tab to navigate to the JavaScript apps:

   ```bash,run
   cd javascript
   ```

2. Install the dependencies:

   ```bash,run
   npm install
   ```

3. Use the Diagrid CLI to run the applications using the Multi-App Run file:

   ```bash,run
   diagrid dev run -f dev-js-state.yaml --project catalyst-demo --approve
   ```

4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "order-app" to ...` in the **Terminal** tab logs before you continue.

5. Use the **curl** tab, and run the following command to make a `POST` request to the `order` endpoint of the `order-app` application:

   ```bash,run
   curl -X POST -H "Content-Type: application/json" -d '{ "orderId": 4 }' http://localhost:5001/order
   ```

   The expected output should contains the ID and a message.

   A new KV pair has been created in the Catalyst KV Store. You can verify this in the last step of this challenge.

6. To retrieve the new KV pair, Use the **curl** tab again, and run the following command to make a `GET` request to the `order/{orderId}` endpoint of the `order-app` application:

   ```bash,run
   curl http://localhost:5001/order/4
   ```

   The expected output should look like this:

   ```json,nocopy
   {"data": {"orderId":4}}
   ```

</details>

## 3. View the Diagrid KV Store service

1. Go to the **Catalyst** tab and navigate to the *Diagrid Services* menu in the left sidebar. Locate the *kvstore* service and drill down into the details.
2. Now, you'll see that there is a `kvstore` component configured and the *Data Explorer* contains the key value pairs which have been created earlier. You might need to refresh the *Data Explorer* to see the latest data.

> [!NOTE]
> If you want to test the K/V service further, you can drill down into the *kvstore* component, locate the *Test API* button in the top right, fill in the AppID `orderapp`, select a state management operation, and a key or message payload such as `{ "orderId": 42 }`. Then click the *Test API* button to test the operation.

## 4. Inspect the Call Graph

Catalyst provides a call graph that shows how the applications interact with each other and with other services such as message brokers and state stores.

1. Use the **Catalyst** tab and navigate to the *Call Graph* menu in the left sidebar.
2. You should see a graph that contains three nodes, two nodes, *publisher* and *subscriber*, related to the previous challenge. And a new node named *order-app*.
3. Click on the *order-app* node and select *Isolate*. The graph changes and will now also show the KV Store service. In addition, the arrow to the KV Store service contains an icon where metrics can be viewed.

> [!NOTE]
> You need to send a couple of requests in order for metrics to be shown in the call graph.

Use the **Terminal** tab and stop the running applications by pressing `Ctrl+C`.

---

Now that you have used the built-in KV Store service in Catalyst let's continue with the next challenge where you'll learn how to use the managed workflow engine Catalyst.