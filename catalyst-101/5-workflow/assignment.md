Catalyst has a managed Dapr workflow engine that is used to reliably run durable workflows. In this challenge, you'll run a Dapr workflow application using Catalyst and visualize the workflow with Catalyst.

## 1. Explore the workflow application

![Workflow demo](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/catalyst-101/5-workflow/images/catalyst-101-workflow.png?raw=true)

The workflow in this challenge simulates a simplified order process. The workflow chains multiple activities together that sends notifications (log statements), checks the inventory and processes the payment. The activities in this application are not implemented to call real services, but they simulate the many steps that occur when ordering a product online.

Choose one of the language tabs to explore the workflow and the activities.

## 3. Run the Dapr workflow application

Now run the applications using the Diagrid CLI. Choose one of the instructions below to run the applications in that language.

<details>
   <summary><b>Run the .NET apps</b></summary>

1. Select the **Terminal** tab and run the following command to navigate to the .NET apps:

```bash,run
cd csharp
```

2. Install the dependencies:

```bash,run
dotnet restore
```

3. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-csharp-workflow.yaml --project catalyst-demo --approve
```

4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "order-workflow" to ...` in the **Terminal** tab logs before you continue.

6. Select the **curl** tab, and run the following command to make a `POST` request to the `start` endpoint of the workflow application:

```bash,run
curl --request POST \
  --url http://localhost:5001/start \
  --header 'content-type: application/json' \
  --data '{"name": "Car","quantity": 2}'
```

7. Switch to the **Terminal** tab to see the logs of the workflow application. The application log should contain output of the notification activities.

Now, let's check the execution of the workflow in Catalyst.

</details>

<details>
   <summary><b>Run the Java apps</b></summary>

1. Use the **Terminal** tab to navigate to the Java apps:

```bash,run
cd java
```

2. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dev-java-workflow.yaml --project catalyst-demo --approve
```

3. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
4. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "order-workflow" to ...` in the **Terminal** tab logs before you continue.

6. Select the **curl** tab, and run the following command to make a `POST` request to the `start` endpoint of the workflow application:

```bash,run
curl --request POST \
  --url http://localhost:5001/start \
  --header 'content-type: application/json' \
  --data '{"name": "Car","quantity": 2}'
```

Switch to the **Terminal** tab to see the logs of the workflow application. The application log should contain output of the notification activities.

Now, let's check the execution of the workflow in Catalyst.

</details>

<details>
   <summary><b>Run the Python apps</b></summary>

1. Use the **Terminal** tab to navigate to the Python apps:

```bash,run
cd python
```

2. Create a virtual environment and activate it:

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
cd ..
diagrid dev run -f dev-python-workflow.yaml --project catalyst-demo --approve
```

5. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
6. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "order-workflow" to ...` in the **Terminal** tab logs before you continue.

8. Select the **curl** tab, and run the following command to make a `POST` request to the `start` endpoint of the workflow application:

```bash,run
curl --request POST \
  --url http://localhost:5001/start \
  --header 'content-type: application/json' \
  --data '{"name": "Car","quantity": 2}'
```

9. Switch to the **Terminal** tab to see the logs of the workflow application. The application log should contain output of the notification activities.

Now, let's check the execution of the workflow in Catalyst.

</details>

<details>
   <summary><b>Run the JavaScript workflow app</b></summary>

1. Use the **Terminal** tab to navigate to the JavaScript app:

```bash,run
cd javascript
```

2. Install the dependencies:

```bash,run
npm install
```

3. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
cd ..
diagrid dev run -f dev-js-workflow.yaml --project catalyst-demo --approve
```

4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "order-workflow" to ...` in the **Terminal** tab logs before you continue.

8. Select the **curl** tab, and run the following command to make a `POST` request to the `start` endpoint of the workflow application:

```bash,run
curl --request POST \
  --url http://localhost:5001/start \
  --header 'content-type: application/json' \
  --data '{"name": "Car","quantity": 2}'
```

9. Switch to the **Terminal** tab to see the logs of the workflow application. The application log should contain output of the notification activities.

Now, let's check the execution of the workflow in Catalyst.

</details>

## 4. View the Catalyst Workflows page

1. Go to the **Catalyst** tab and open the *Workflows* page.
2. You should now see an entry for the *OrderProcessingWorkflow* with as successful status.
3. Select the workflow instance to drill down into the details of the workflow. This leads to a page with some statistics about the workflow executions and a visual representation of the workflow.
4. Select the workflow execution entry on the right or bottom side of the visual representation to drill down into the details of this workflow instance.
5. You'll now see the start- and end time of the workflow, the execution time, the instance ID, the input and output of the workflow, and an interactive visualization of the workflow execution.select some of the nodes in the graph to see the input and output of the activities.

---

You now know how to use Catalyst to run Dapr workflow applications, and how to use the visualization of the workflow to inspect the workflow execution.

## Collect your badge & provide feedback

Congratulations! 🎉 You've completed the Dapr University Running Dapr Applications with Catalyst learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving this training 🚀.

All code samples shown in this Dapr University track are available in the [Catalyst Quickstarts](https://github.com/diagridio/catalyst-quickstarts/) and [Dapr QuickStarts](https://github.com/dapr/quickstarts/) repositories.

Collect the Dapr University badge for this track by following [this link to the Holopin platform](https://holopin.io/collect/cmggddbde003vlg04ubjknxvm). You'll need a GitHub account to claim the badge.

[![Dapr University Catalyst 101 badge](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/catalyst-101/Diagrid-Dapr-Uni-Catalyst-101_x500.png?raw=true)](https://holopin.io/collect/cmggddbde003vlg04ubjknxvm)

 If you have any questions or feedback about this track, you can let us know in the [Diagrid Discord server](https://diagrid.ws/diagrid-discord).
