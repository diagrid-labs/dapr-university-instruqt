Catalyst has a managed Dapr workflow engine that is used to reliably run durable workflows. In this challenge, you'll run a Dapr workflow application using Catalyst and visualize the workflow with Catalyst.

## 1. View the Catalyst Workflows page

1. Select the **Catalyst** tab, use the left sidebar to navigate to the *Workflows* menu item and select it.
2. You'll see a *Workflows* page that is currently empty. Once you run the workflow application in the next steps, this is where you can find workflow instance data and workflow visualizations.

## 2. Explore the fan-out/fan-in workflow application

![Fan-out/Fan-in](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow/4-fan-out-fan-in/images/dapr-uni-wf-pattern-fan-out-fan-in-v1.png?raw=true)

The fan-out/fan-in pattern is used when there is no dependency between the activities in the workflow. The activities can be executed in parallel, the workflow will wait until all activities are completed and the results from the activities can be aggregated into a single result.

The workflow in this challenge uses the fan-out/fan-in pattern to determine the shortest word in an array of words.

- The workflow is started with an input of an array of words `["which","word","is","the","shortest"]`.
- For each of the words in the array, an activity is created that determines the length of the word.
- Once all the tasks are created, they are scheduled in parallel and the workflow waits until they are all completed.
- The workflow then aggregates the results and returns the shortest word: `"is"`.

Choose one of the language tabs to explore the code. For each language, there is one Dapr workflow application that uses the fan-out/fan-in pattern to orchestrate multiple activities.

## 3. Run the Dapr workflow application

Now run the applications using the Diagrid CLI. Choose one of the instructions below to run the applications in that language.

<details>
   <summary><b>Run the .NET apps</b></summary>

1. Select the **Terminal** tab and run the following command to navigate to the .NET apps:

```bash,run
cd csharp/fan-out-fan-in
```

2. Use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
diagrid dev run -f dapr.yaml
```

3. You'll be asked to deploy to the project you just created. Select `Y` to proceed.
4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "order-app" to ...` in the **Terminal** tab logs before you continue.

6. Select the **curl** tab, and run the following command to make a `POST` request to the `start` endpoint of the `faninfanout` application:

```bash,run
curl --request POST \
  --url http://localhost:5256/start \
  --header 'content-type: application/json' \
  --data '["which","word","is","the","shortest"]'
```

7. Switch to the **Terminal** tab to see the logs of the workflow application. The application log should contain output like this:

```text,nocopy
== APP - fanoutfanin == GetWordLength: Received input: is.
== APP - fanoutfanin == GetWordLength: Received input: which.
== APP - fanoutfanin == GetWordLength: Received input: the.
== APP - fanoutfanin == GetWordLength: Received input: shortest.
== APP - fanoutfanin == GetWordLength: Received input: word.
```

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
diagrid dev run -f dapr.yaml
```

3. You'll be asked to deploy to the project you just created. Select `Y` and `Enter` to proceed.
4. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
5. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "faninfanout" to ...` in the **Terminal** tab logs before you continue.

6. Select the **curl** tab, and run the following command to make a `POST` request to the `start` endpoint of the `faninfanout` application:

```bash,run
curl -i --request POST \
  --url http://localhost:8080/start \
  --header 'content-type: application/json' \
  --data '["which","word","is","the","shortest"]'
```

Switch to the **Terminal** tab to see the logs of the workflow application. The application log should contain output like this:

```text,nocopy
io.dapr.workflows.WorkflowContext        : Starting Workflow: io.dapr.springboot.examples.fanoutfanin.FanOutFanInWorkflow
i.d.s.e.f.GetWordLengthActivity          : io.dapr.springboot.examples.fanoutfanin.GetWordLengthActivity : Received input: which
i.d.s.e.f.GetWordLengthActivity          : io.dapr.springboot.examples.fanoutfanin.GetWordLengthActivity : Received input: the
i.d.s.e.f.GetWordLengthActivity          : io.dapr.springboot.examples.fanoutfanin.GetWordLengthActivity : Received input: shortest
i.d.s.e.f.GetWordLengthActivity          : io.dapr.springboot.examples.fanoutfanin.GetWordLengthActivity : Received input: word
i.d.s.e.f.GetWordLengthActivity          : io.dapr.springboot.examples.fanoutfanin.GetWordLengthActivity : Received input: is
```

Now, let's check the execution of the workflow in Catalyst.

</details>

<details>
   <summary><b>Run the Python apps</b></summary>

1. Use the **Terminal** tab to navigate to the Python apps:

```bash,run
cd python/fan-out-fan-in/fan_out_fan_in
```

2. Create a virtual environment and activate it:

```bash,run
python3 -m venv venv
source venv/bin/activate
```

3. Install the dependencies:

```bash,run
pip3 install -r requirements.txt
```

4. Move one folder up and use the Diagrid CLI to run the applications using the Multi-App Run file:

```bash,run
cd ..
diagrid dev run -f dapr.yaml
```

5. You'll be asked to deploy to the project you just created. Select `Y` and `Enter` to proceed.
6. You can switch to the **Catalyst** tab to see the application IDs and resources being deployed.
7. Wait until the the two applications are connected to Catalyst.

> [!IMPORTANT]
> You need to wait until the Diagrid CLI has set up a connection with the newly created resources in Catalyst. You should see `Connected App ID "faninfanout" to ...` in the **Terminal** tab logs before you continue.

8. Select the **curl** tab, and run the following command to make a `POST` request to the `start` endpoint of the `faninfanout` application:

```bash,run
curl --request POST \
  --url http://localhost:5256/start \
  --header 'content-type: application/json' \
  --data '["which","word","is","the","shortest"]
```

9. Switch to the **Terminal** tab to see the logs of the workflow application. The application log should contain output like this:

```text,nocopy
== APP - fanoutfanin == get_word_length: Received input: is.
== APP - fanoutfanin == get_word_length: Received input: which.
== APP - fanoutfanin == get_word_length: Received input: the.
== APP - fanoutfanin == get_word_length: Received input: shortest.
== APP - fanoutfanin == get_word_length: Received input: word.
```

Now, let's check the execution of the workflow in Catalyst.

</details>

## 4. View the Catalyst Workflows page

1. Go back to the **Catalyst** tab and open the *Workflows* page.
2. You should now see an entry for the *FanOutFanInWorkflow* with as successful status.
3. Select the workflow instance to drill down into the details of the workflow. This leads to a page with some statistics about the workflow executions and a visual representation of the workflow.
4. Select the workflow execution entry on the right side of the visual representation to drill down into the details of this workflow instance.
5. You'll now see the start- and end time of the workflow, the execution time, the instance ID, the input and output of the workflow, and an interactive visualization of the workflow execution.select some of the nodes in the graph to see the input and output of the activities.

---

You now know how to use Catalyst to run Dapr workflow applications, and how to use the visualization of the workflow to inspect the workflow execution.

## Collect your badge & provide feedback

Congratulations! 🎉 You've completed the Dapr University Running Dapr Applications with Catalyst learning track! Please take a moment to rate this training and provide feedback in the next step so we can keep improving this training 🚀.

All code samples shown in this Dapr University track are available in the [Catalyst Quickstarts](https://github.com/diagridio/catalyst-quickstarts/) and [Dapr QuickStarts](https://github.com/dapr/quickstarts/) repositories.

Collect the Dapr University badge for this track by following [this link to the Holopin platform](https://holopin.io/collect/cmggddbde003vlg04ubjknxvm). You'll need a GitHub account to claim the badge.

[![Dapr University Catalyst 101 badge](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/catalyst-101/Diagrid-Dapr-Uni-Catalyst-101_x500.png?raw=true)](https://holopin.io/collect/cmggddbde003vlg04ubjknxvm)

 If you have any questions or feedback about this track, you can let us know in the [Diagrid Discord server](https://diagrid.ws/diagrid-discord).
