In this challenge, you'll explore a more realistic example of a workflow application, that uses several workflow patterns and multiple Dapr APIs.

## 1. Combined Patterns

It's common for a workflow to combine different workflow patterns such as task chaining, fan-out/fan-in, and waiting for external events. Dapr workflow works great with the other Dapr APIs, such as state management, pub/sub, secrets, and bindings. These APIs always need to be used in activities, and not in the workflow code.

In this challenge, you'll explore a Workflow App that interacts with a state store, and communicates with another Dapr application, Shipping App, via service invocation and pub/sub.

![Combined patterns](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/9-combined-patterns/images/dapr-uni-wf-combined-patterns-demo-v1.png?raw=true)

The workflow simulates an order processing flow:

- The workflow is started with an order object as the input argument.
- Two checks are done in a fan-out/fan-in pattern:
  - An inventory check is done to verify if the ordered item is in stock.
  - A shipping destination check is done to verify that the shipping provider can ship the item to the destination.
- If both checks are successful, an activity is called to process the payment.
- The inventory is updated.
- The shipment is registered with the Shipping App via pub/sub.
- The Shipping App publishes a message back to the Workflow App.
- The workflow waits for this message to arrive and based on the payload of the event, the workflow either completes successfully or an activity is called to reimburse the customer (the compensation action).

### 1.1 Choose a language tab

Use one of the language tabs to navigate to the combined patterns example. Each language tab contains a workflow application, a shipping application, and a Multi-App Run `dapr.yaml` file that is used to run the example.

### 1.2 Inspect the Workflow code

> [!NOTE]
> Expand the language-specific instructions to learn more about the workflow.

<details>
   <summary><b>.NET workflow code</b></summary>

Open the `OrderWorkflow.cs` file located in the `WorkflowApp` folder. This file contains the workflow code.

</details>

<details>
   <summary><b>Python workflow code</b></summary>

Open the `order_workflow.py` file located in the `workflow_app` folder. This file contains the workflow code.

</details>

### 1.3 Inspect the Activity code

> [!NOTE]
> Expand the language-specific instructions to learn more about the activities.

<details>
   <summary><b>.NET activity code</b></summary>

The activity definitions are located in the `WorkflowApp/Activities` folder. The activities are:

- `CheckInventory`: checks if the item is in stock. This activity uses the Dapr state management API to check the inventory.
- `CheckShippingDestination`: checks if the item can be shipped to the destination. This activity uses the Dapr service invocation API to call the `checkDestination` method on the Shipping App.
- `ProcessPayment`: simulates a payment process. This activity only logs the input and returns a success message.
- `UpdateInventory`: updates the inventory. This activity uses the Dapr state management API to update inventory.
- `RegisterShipment`: registers the shipment with the Shipping App. This activity uses the Dapr pub/sub API to publish a message to the `shipment-registration-events` topic.
- `ReimburseCustomer`: simulates a reimbursement for the customer. This activity only logs the input and returns a success message.

</details>

<details>
   <summary><b>Python activity code</b></summary>

The activity definitions are located in the `order_workflow.py` file below the workflow definition. The activities are:

- `check_inventory`: checks if the item is in stock. This activity uses the Dapr state management API to check the inventory.
- `check_shipping_destination`: checks if the item can be shipped to the destination. This activity uses the Dapr service invocation API to call the `checkDestination` method on the Shipping App.
- `process_payment`: simulates a payment process. This activity only logs the input and returns a success message.
- `update_inventory`: updates the inventory. This activity uses the Dapr state management API to update inventory.
- `register_shipment`: registers the shipment with the Shipping App. This activity uses the Dapr pub/sub API to publish a message to the `shipment-registration-events` topic.
- `reimburse_customer`: simulates a reimbursement for the customer. This activity only logs the input and returns a success message.

</details>

### 1.4. Inspect the startup code

> [!NOTE]
> Expand the language-specific instructions to learn more about workflow registration, workflow runtime startup, and HTTP endpoints to start the workflow.

<details>
   <summary><b>.NET registration and endpoints</b></summary>

Locate the `Program.cs` file in the `WorkflowApp` folder. This file contains the code to register the workflows and activities using the `AddDaprWorkflow()` extension method.

Th WorkflowApp has the following HTTP endpoints:

- `start`, a POST endpoint that is used to start the workflow, and accepts an `Order` as the input.
- `shipmentRegistered`, a POST endpoint that is used to receive the shipment registration event from the Shipping App sent via pub/sub messaging. This endpoint uses the `DaprWorkflowClient` to raise an external event to the workflow instance with the shipment registration status.

</details>

<details>
   <summary><b>Python workflow runtime and endpoints</b></summary>

Locate the `app.py` file in the `workflow_app` folder. This file contains the code to start the workflow runtime and two HTTP endpoints:

- `start`, a POST endpoint that is used to start the workflow, and accepts an `Order` as the input.
- `shipmentRegistered`, a POST endpoint that is used to receive the shipment registration event from the Shipping App sent via pub/sub messaging. This endpoint uses the `DaprWorkflowClient` to raise an external event to the workflow instance with the shipment registration status.

</details>

### 1.5. Inspect the Shipping App

> [!NOTE]
> Expand the language-specific instructions to learn more about the shipping application.

<details>
   <summary><b>.NET shipping app</b></summary>

Locate the `Program.cs` file in the `ShippingApp` folder. This file contains the following HTTP endpoints:

- `checkDestination`, a POST endpoint that that simulates a check if the shipper can ship to the destination. This endpoint is called by the `CheckShippingDestination` activity via service invocation. This method always returns a success message.
- `registerShipment`, a POST endpoint that is used to simulate the registration of a new shipment. This endpoint is handling messages for the subscription of the `shipment-registration-events` topic (published by the WorkflowApp). The method publishes a success status message to the `shipment-registration-confirmed-events` topic as long the order ID is not empty. This is because the order ID is used as the workflow instance ID, and the subscriber to this topic (`shipmentRegistered` method in the WorkflowApp) needs the workflow instance ID to raise an event to that workflow instance.

</details>

<details>
   <summary><b>Python shipping app</b></summary>

Locate the `app.py` file in the `shipping_app` folder. This file contains the following HTTP endpoints:

- `checkDestination`, a POST endpoint that that simulates a check if the shipper can ship to the destination. This endpoint is called by the `check_shipping_destination` activity via service invocation. This method always returns a success message.
- `registerShipment`, a POST endpoint that is used to simulate the registration of a new shipment. This endpoint is handling messages for the subscription of the `shipment-registration-events` topic (published by the WorkflowApp). The method publishes a success status message to the `shipment-registration-confirmed-events` topic. The order ID is used as the workflow instance ID, and the subscriber to this topic (`shipmentRegistered` method in the WorkflowApp) needs the workflow instance ID to raise an event to that workflow instance.

</details>

### 1.6. Inspect the Dapr component files

Since the Dapr applications in the challenge use the Dapr pub/sub API, they also require Dapr component files to configure the pub/sub component and the (declarative) subscriptions. These component files can be found in the `resources` folder.

## 2. Run the workflow app

> [!NOTE]
> Expand the language specific instructions to start the combined patterns workflow.

<details>
   <summary><b>Run the .NET application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *csharp/combined-patterns* folder:

```bash,run
cd csharp/combined-patterns
```

Install the dependencies and build the projects:

```bash,run
dotnet build ShippingApp
dotnet build WorkflowApp
```

Run the applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

<details>
   <summary><b>Run the Python application</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *python/combined-patterns* folder:

```bash,run
cd python/combined-patterns
```

Create a virtual environment and activate it:

```bash,run
python3 -m venv venv
source venv/bin/activate
```

Install the dependencies for the workflow_app:

```bash,run
cd workflow_app
pip3 install -r requirements.txt
cd ..
```

Install the dependencies for the shipping_app:

```bash,run
cd shipping_app
pip3 install -r requirements.txt
cd ..
```

Run the applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>

###

> [!IMPORTANT]
> Inspect the output of the **Dapr CLI** window. Wait until the application is running before continuing.

## 3. Start the workflow

Use the **curl** window to make a POST request to the `start` endpoint of the workflow application.

> [!NOTE]
> Expand the language-specific instructions to start the combined patterns workflow.

<details>
   <summary><b>Start the .NET workflow</b></summary>

In the **curl** window, run the following command to start the workflow:

```curl,run
curl -i --request POST \
   --url http://localhost:5260/start \
   --header 'content-type: application/json' \
   --data '{"id": "b0d38481-5547-411e-ae7b-255761cce17a","orderItem" : {"productId": "RBD001","productName": "Rubber Duck","quantity": 10,"totalPrice": 15.00},"customerInfo" : {"id" : "Customer1","country" : "The Netherlands"}}'
```

Expected output:

```text
HTTP/1.1 202 Accepted
Content-Length: 0
Date: Wed, 23 Apr 2025 12:08:02 GMT
Server: Kestrel
Location: b0d38481-5547-411e-ae7b-255761cce17a
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - order-workflow == CheckInventory: Received input: OrderItem { ProductId = RBD001, ProductName = Rubber Duck, Quantity = 10, TotalPrice = 15.00 }.
== APP - order-workflow == CheckShippingDestination: Received input: Order { Id = 06d49c54-bf65-427b-90d1-730987e96e61, OrderItem = OrderItem { ProductId = RBD001, ProductName = Rubber Duck, Quantity = 10, TotalPrice = 15.00 }, CustomerInfo = CustomerInfo { Id = Customer1, Country = The Netherlands } }.
== APP - shipping == checkDestination: Received input: Order { Id = 06d49c54-bf65-427b-90d1-730987e96e61, OrderItem = OrderItem { ProductId = RBD001, ProductName = Rubber Duck, Quantity = 10, TotalPrice = 15.00 }, CustomerInfo = CustomerInfo { Id = Customer1, Country = The Netherlands } }.
== APP - order-workflow == ProcessPayment: Received input: Order { Id = 06d49c54-bf65-427b-90d1-730987e96e61, OrderItem = OrderItem { ProductId = RBD001, ProductName = Rubber Duck, Quantity = 10, TotalPrice = 15.00 }, CustomerInfo = CustomerInfo { Id = Customer1, Country = The Netherlands } }.
== APP - order-workflow == UpdateInventory: Received input: OrderItem { ProductId = RBD001, ProductName = Rubber Duck, Quantity = 10, TotalPrice = 15.00 }.
== APP - order-workflow == RegisterShipment: Received input: Order { Id = 06d49c54-bf65-427b-90d1-730987e96e61, OrderItem = OrderItem { ProductId = RBD001, ProductName = Rubber Duck, Quantity = 10, TotalPrice = 15.00 }, CustomerInfo = CustomerInfo { Id = Customer1, Country = The Netherlands } }.
== APP - shipping == registerShipment: Received input: Order { Id = 06d49c54-bf65-427b-90d1-730987e96e61, OrderItem = OrderItem { ProductId = RBD001, ProductName = Rubber Duck, Quantity = 10, TotalPrice = 15.00 }, CustomerInfo = CustomerInfo { Id = Customer1, Country = The Netherlands } }.
== APP - order-workflow == Shipment registered for order ShipmentRegistrationStatus { OrderId = 06d49c54-bf65-427b-90d1-730987e96e61, IsSuccess = True, Message = }
```

</details>

<details>
   <summary><b>Start the Python workflow</b></summary>

In the **curl** window, run the following command to start the workflow:

```curl,run
curl -i --request POST \
   --url http://localhost:5260/start \
   --header 'content-type: application/json' \
   --data '{"id": "b0d38481-5547-411e-ae7b-255761cce17a","order_item" : {"product_id": "RBD001","product_name": "Rubber Duck","quantity": 10,"total_price": 15.00},"customer_info" : {"id" : "Customer1","country" : "The Netherlands"}}'
```

Expected output:

```text
HTTP/1.1 202 Accepted
date: Tue, 20 May 2025 11:00:06 GMT
server: uvicorn
content-length: 54
content-type: application/json

{"instance_id":"b0d38481-5547-411e-ae7b-255761cce17a"}
```

The **Dapr CLI** window should contain these application log statements:

```text,nocopy
== APP - order-workflow == order_workflow: Received order id: b0d38481-5547-411e-ae7b-255761cce17a.
== APP - order-workflow == check_inventory: Received input: product_id='RBD001' product_name='Rubber Duck' quantity=10 total_price=15.0.
== APP - order-workflow == check_shipping_destination: Received input: id='Customer1' country='The Netherlands'.
== APP - order-workflow == get_inventory_item: product_id='RBD001' product_name='Rubber Duck' quantity=50
== APP - shipping == checkDestination: Received input: id='Customer1' country='The Netherlands'.
== APP - order-workflow == process_payment: Received input: id='b0d38481-5547-411e-ae7b-255761cce17a' order_item=OrderItem(product_id='RBD001', product_name='Rubber Duck', quantity=10, total_price=15.0) customer_info=CustomerInfo(id='Customer1', country='The Netherlands').
== APP - order-workflow == order_workflow: Payment result: is_success=True.
== APP - order-workflow == update_inventory: Received input: product_id='RBD001' product_name='Rubber Duck' quantity=10 total_price=15.0.
== APP - order-workflow == get_inventory_item: product_id='RBD001' product_name='Rubber Duck' quantity=50
== APP - order-workflow == register_shipment: Received input: id='b0d38481-5547-411e-ae7b-255761cce17a' order_item=OrderItem(product_id='RBD001', product_name='Rubber Duck', quantity=10, total_price=15.0) customer_info=CustomerInfo(id='Customer1', country='The Netherlands').
== APP - shipping == registerShipment: Received input: id='b0d38481-5547-411e-ae7b-255761cce17a' order_item=OrderItem(product_id='RBD001', product_name='Rubber Duck', quantity=10, total_price=15.0) customer_info=CustomerInfo(id='Customer1', country='The Netherlands').
== APP - order-workflow == shipmentRegistered: Received input: order_id='b0d38481-5547-411e-ae7b-255761cce17a' is_success=True message=None.
== APP - order-workflow == 2025-05-20 11:00:07.533 durabletask-client INFO: Raising event 'shipment-registered-events' for instance 'b0d38481-5547-411e-ae7b-255761cce17a'.
== APP - order-workflow == 2025-05-20 11:00:07.541 durabletask-worker INFO: b0d38481-5547-411e-ae7b-255761cce17a Event raised: shipment-registered-events
== APP - order-workflow == 2025-05-20 11:00:07.541 durabletask-worker INFO: b0d38481-5547-411e-ae7b-255761cce17a: Orchestration completed with status: COMPLETED
```

</details>

## 4. Get the workflow status

Use the **curl** window to perform a GET request directly the Dapr workflow management API to retrieve the workflow status.

> [!NOTE]
> Expand the language-specific instructions to get the workflow instance status.

<details>
   <summary><b>Get the .NET workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3560/v1.0/workflows/dapr/b0d38481-5547-411e-ae7b-255761cce17a
```

Expected output:

```json,nocopy
{
   "instanceID":"b0d38481-5547-411e-ae7b-255761cce17a",
   "workflowName":"OrderWorkflow",
   "createdAt":"2025-04-23T12:08:02.625836530Z",
   "lastUpdatedAt":"2025-04-23T12:08:03.149685594Z",
   "runtimeStatus":"COMPLETED",
   "properties":{
      "dapr.workflow.input":"{\"Id\":\"b0d38481-5547-411e-ae7b-255761cce17a\",\"OrderItem\":{\"ProductId\":\"RBD001\",\"ProductName\":\"Rubber Duck\",\"Quantity\":10,\"TotalPrice\":15.00},\"CustomerInfo\":{\"Id\":\"Customer1\",\"Country\":\"The Netherlands\"}}",
      "dapr.workflow.output":"{\"IsSuccess\":true,\"Message\":\"Order b0d38481-5547-411e-ae7b-255761cce17a processed successfully.\"}"
   }
}
```

</details>

<details>
   <summary><b>Get the Python workflow status</b></summary>

Use the **curl** window to make a GET request to get the status of a workflow instance:

```curl,run
curl --request GET --url http://localhost:3560/v1.0/workflows/dapr/b0d38481-5547-411e-ae7b-255761cce17a
```

Expected output:

```json,nocopy
{
   "instanceID":"b0d38481-5547-411e-ae7b-255761cce17a",
   "workflowName":"order_workflow",
   "createdAt":"2025-04-23T12:08:02.625836530Z",
   "lastUpdatedAt":"2025-04-23T12:08:03.149685594Z",
   "runtimeStatus":"COMPLETED",
   "properties":{
      "dapr.workflow.input":"{\"id\": \"b0d38481-5547-411e-ae7b-255761cce17a\", \"order_item\": {\"product_id\": \"RBD001\", \"product_name\": \"Rubber Duck\", \"quantity\": 10, \"total_price\": 15.0}, \"customer_info\": {\"id\": \"Customer1\", \"country\": \"The Netherlands\"}}",
      "dapr.workflow.output":"{\"is_success\": true, \"message\": \"Order b0d38481-5547-411e-ae7b-255761cce17a processed successfully.\"}"
   }
}
```

</details>

## 5. Stop the workflow application

Use the **Dapr CLI** window to stop the workflow application by pressing `Ctrl+C`.

---

You've now seen and run a more realistic workflow that uses multiple patterns and Dapr APIs. Now, let's continue with the workflow management APIs, because you can do more than starting a workflow and getting the state of a workflow instance.
