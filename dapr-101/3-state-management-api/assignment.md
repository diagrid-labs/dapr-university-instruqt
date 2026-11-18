# Use the State Management API

The goal of this lab is to run the Dapr sidecar in self-hosted mode and use the State Management HTTP API to interact with a state store. You do this without running any application code: you make HTTP requests with cURL and send them to the Dapr process. This hands-on lab takes about 5 minutes to complete.

## Before you start

The terminals, and the applications running in them, stay as they are when you move between labs. Open the **Dev Dashboard** tab and look at which applications are running. If any are, use the **Dapr CLI** window to stop them by pressing `Ctrl+C`. Then go back to the **Editor** tab.

## 1. Run a Dapr sidecar

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

First a Dapr sidecar process needs to be started. Run this command in the **Dapr CLI** window:

```bash,run
dapr run --app-id myapp --dapr-http-port 3500
```

> [!NOTE]
> When you run a Dapr process, you always need to specify an `app-id` that identifies your application. In this case there is no application but you're executing cURL commands, so in a sense you are the application that uses the Dapr API.

A lot of output will be printed by running this command. The last few lines should contain:

```text,nocopy
ℹ️  Dapr sidecar is up and running.
✅  You're up and running! Dapr logs will appear here.
```

Open the **Dev Dashboard** tab and go to the **Applications** page: `myapp` is listed there, and its sidecar is ready when the **Health** column shows a green dot. Then go back to the **Editor** tab.

If you scroll up in the **Dapr CLI** window you'll find this info statement that tells you what type of storage Dapr is using in this demo:

```text,nocopy
INFO[0000] Component loaded: statestore (state.redis/v1)
```

At the end of this lab you'll inspect this in more detail.

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

Now look at how the state is stored. Open the **Dev Dashboard** tab and go to the **State** page. It lists the records in the state store: find the record with the key `name` and the app prefix `myapp`, and expand it to see its value, `"Bruce Wayne"`. Then go back to the **Editor** tab.

> [!NOTE]
> Note that the record belongs to the app `myapp`: Dapr stores the key with the `app-id` as prefix (`myapp||name`). This is the default behaviour in Dapr. Every application manages their data via the `app-id` prefix. If you want multiple applications to access the same data you can change this by configuring the state store component, see [Specifying a state prefix strategy](https://docs.dapr.io/developing-applications/building-blocks/state-management/howto-share-state/) in the Dapr Docs.

## 5. Delete state

Run the following command in the **curl** window to delete the key/value pair:

```bash,run
curl -v -X DELETE -H "Content-Type: application/json" http://localhost:3500/v1.0/state/statestore/name
```

## 6. Verify the state is deleted

Open the **Dev Dashboard** tab and go to the **State** page again. The record with the key `name` is gone. Then go back to the **Editor** tab.

## 7. Stop the applications

Use the **Dapr CLI** window to stop the sidecar by pressing `Ctrl+C`.

The output should be:

```text,nocopy
terminated signal received: shutting down
✅  Exited Dapr successfully
```

## 8. Inspect the state store component file

Dapr knows to use Redis as the default state store when `statestore` is used in the State Management API endpoint because Dapr reads a component file that contains this definition. When Dapr is initialized with the CLI, several default component files are placed in the `.dapr/components` folder in the user profile.

Use the **Dapr CLI** window to run the following command to show the content of the default `statestore.yaml` component file in the user profile:

```bash,run
cat ~/.dapr/components/statestore.yaml
```

The output should be:

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

---

Now you know how the Dapr State Management HTTP API can be used to manage key/value data.

## What's next?

Normally you would write an application that uses the Dapr API and not make cURL requests yourself. So in the next lab, "Use the Service Invocation API", you'll run applications that call each other through the Dapr API.
