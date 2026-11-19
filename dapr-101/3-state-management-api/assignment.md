# Use the State Management API

The goal of this lab is to run the Dapr sidecar in self-hosted mode and use the State Management HTTP API to interact with a state store. You do this without running any application code: you make HTTP requests with cURL and send them to the Dapr process. This hands-on lab takes about 5 minutes to complete.

## 1. Run a Dapr sidecar

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

First a Dapr sidecar process needs to be started. Use the **Editor** tab and open `state-management/dapr.yaml`:

```yaml,nocopy
version: 1
apps:
  - appID: myapp
    appDirPath: .
    daprHTTPPort: 3500
```

This file is a Dapr *Multi-App Run* template. It describes one or more applications that the Dapr CLI starts together, each with its own Dapr sidecar, when you run `dapr run -f .` in the folder that holds it. This template describes one entry under `apps`:

- `version: 1` is the version of the template format.
- `appID: myapp` is the app ID of the sidecar. Dapr uses it to identify the application, for example to call it with service invocation or to keep its state apart from the state of other applications.
- `appDirPath: .` is the folder of the application, relative to `dapr.yaml`. The Dapr CLI starts the application there and writes its log files to a `.dapr/logs` folder inside it.
- `daprHTTPPort: 3500` fixes the port of the sidecar's HTTP API. Without it, the Dapr CLI picks a free port. A fixed port makes the cURL commands in this lab predictable.

Two settings are missing on purpose:

- There is no `command`, which is the command that starts the application. Without it, the Dapr CLI only starts the sidecar: you make the HTTP requests with cURL yourself.
- There is no `resourcesPaths`, which lists the folders with component files. Without it, the sidecar loads the default components that `dapr init` placed in `~/.dapr/components`. One of them is the `statestore` component you'll use in this lab.

For more information on Multi-App Run, see the [Dapr Docs](https://docs.dapr.io/developing-applications/local-development/multi-app-dapr-run/multi-app-overview/).

> [!NOTE]
> Dapr always needs an app ID that identifies your application. In this case there is no application but you're executing cURL commands, so in a sense you are the application that uses the Dapr API.

Use the **Dapr CLI** window to go to the `state-management` folder:

```bash,run
cd /root/university-labs/dapr-101/state-management
```

Start the sidecar with the Dapr CLI:

```bash,run
dapr run -f .
```

The output should contain these lines. The gRPC port number can differ:

```text,nocopy
⚠  No application command found for app "myapp" present in dapr.yaml
ℹ️  Started Dapr with app id "myapp". HTTP Port: 3500. gRPC Port: 50001
ℹ️  Writing log files to directory : /root/university-labs/dapr-101/state-management/.dapr/logs
```

The warning is expected, since the template has no `command`. Because you started the sidecar from a run template, the Dapr CLI writes the sidecar logs to a file in the `.dapr/logs` folder instead of the terminal, and the **Dev Dashboard** shows them. A plain `dapr run` without a template only prints the logs in the terminal.

Open the **Dev Dashboard** tab and go to the **Applications** page: `myapp` is listed there, and its sidecar is ready when the **Health** column shows a green dot.

Now go to the **Logs** page, select `myapp` in the application drop-down, and type `Component loaded` in the search bar. The page shows the `app` and `daprd` (sidecar) logs together, and you'll find this sidecar line, which tells you what type of storage Dapr is using in this demo:

```text,nocopy
Component loaded: statestore (state.redis/v1)
```

Then go back to the **Editor** tab. At the end of this lab you'll inspect this component in more detail.

## 2. Save state

You're going to make a `POST` request to the `v1.0/state/statestore` endpoint of the Dapr sidecar that is running on `localhost` and port `3500`.
- The `/state` part of the endpoint indicates the State Management API will be used.
- The `/statestore` part of the endpoint indicates the name of the state store component that will be used. The underlying state store component is the `dapr_redis` container that was initialized by `dapr init`. We'll have a look at the component file at the end of this lab.

Run the following command in the **curl** window:

```bash,run
curl -X POST -H "Content-Type: application/json" -d '[{ "key": "name", "value": "Bruce Wayne"}]' http://localhost:3500/v1.0/state/statestore
```

*There will be no return value for this command.*

> [!NOTE]
> Note that the State Management API is based on managing key/value objects. If you're looking for SQL based functionality look into [Dapr bindings](https://docs.dapr.io/developing-applications/building-blocks/bindings/bindings-overview/) in the Dapr docs.

## 3. Get state

Run the following command in the **curl** window to retrieve the state you just saved:

```bash,run
curl http://localhost:3500/v1.0/state/statestore/name
```

The output should be:

```text,nocopy
"Bruce Wayne"
```

## 4. Inspect the state on the Dev Dashboard

Now look at how the state is stored. Open the **Dev Dashboard** tab and go to the **State** page. It lists the records in the state store: find the record with the key `name` and the app prefix `myapp`. Its value, `"Bruce Wayne"`, is shown in the list. Then go back to the **Editor** tab.

> [!NOTE]
> Note that the record belongs to the app `myapp`: Dapr stores the key with the `app-id` as prefix (`myapp||name`). This is the default behaviour in Dapr. Every application manages their data via the `app-id` prefix. If you want multiple applications to access the same data you can change this by configuring the state store component, see [Specifying a state prefix strategy](https://docs.dapr.io/developing-applications/building-blocks/state-management/howto-share-state/) in the Dapr Docs.

## 5. Delete state

Run the following command in the **curl** window to delete the key/value pair:

```bash,run
curl -v -X DELETE -H "Content-Type: application/json" http://localhost:3500/v1.0/state/statestore/name
```

## 6. Verify the state is deleted

Open the **Dev Dashboard** tab and go to the **State** page again. The record with the key `name` is gone.

## 7. Stop the applications

Use the **Dapr CLI** window to stop the sidecar by pressing `Ctrl+C`.

The output should be:

```text,nocopy
ℹ️  Received signal to stop Dapr and app processes. Shutting down Dapr and app processes.
```

## 8. Inspect the state store component file

Dapr knows to use Redis as the default state store when `statestore` is used in the State Management API endpoint because Dapr reads a component file that contains this definition. When Dapr is initialized with the CLI, several default component files are placed in the `.dapr/components` folder in the user profile. The sidecar loaded them because the run template has no `resourcesPaths`.

Open the **Dev Dashboard** tab and go to the **Components** page. It lists the components in `~/.dapr/components`. Select the `statestore` item to load its YAML file:

```yaml,nocopy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
  - name: actorStateStore
    value: "true"
```

> [!NOTE]
> The value of `metadata.name` is `statestore`, this is the same name that is used in the cURL commands to identify this component.
>
> The value of `spec.type` is `state.redis`, and this indicates Redis is used as a state store.
>
> The `metadata` section is specific to each type of component and will have different fields.

Then go back to the **Editor** tab.

---

Now you know how the Dapr State Management HTTP API can be used to manage key/value data.

## What's next?

Normally you would write an application that uses the Dapr API and not make cURL requests yourself. So in the next lab, "Use the Service Invocation API", you'll run applications that call each other through the Dapr API.
