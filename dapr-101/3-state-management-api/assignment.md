# Use the Dapr State Management API

The goal of this challenge is to run the Dapr sidecar in self-hosted mode and use the State Management HTTP API to interact with a state store. This is done without running any application code but by making HTTP  requests using cURL and sending these to the Dapr process.

## 1. Run a Dapr sidecar

First a Dapr sidecar process needs to be started. Run this command in the *Dapr sidecar terminal*:

```bash,run
dapr run --app-id myapp --dapr-http-port 3500
```

>[!IMPORTANT]
>When you run a Dapr process, you always need to specify an `app-id` that identifies your application. In this case there is no application but you're executing cURL commands, so in a sense you are the application that uses the Dapr API.

A lot of output will be printed by running this command. The last few lines should contain:

```text,nocopy
ℹ️  Dapr sidecar is up and running.
✅  You're up and running! Dapr logs will appear here.
```

If you scroll up in the *Dapr sidecar terminal* you'll find this info statement that tells you what type of storage Dapr is using in this demo:

```text,nocopy
INFO[0000] Component loaded: statestore (state.redis/v1)
```

In section 6 of this challenge you'll inspect this in more detail.

## 2. Save state

You're going to make a `POST` request to the `v1.0/state/statestore` endpoint of the Dapr sidecar that is running on `localhost` and port `3500`.
- The `/state` part of the endpoint indicates the State Management API will be used.
- The `/statestore` part of the endpoint indicates the name of the state store component that will be used. The underlying state store component is the `dapr_redis` container that was initialized during the Dapr CLI setup. We'll have a look at the component file at the end of this challenge.

Run the following command in the *cURL terminal*:

```bash,run
curl -X POST -H "Content-Type: application/json" -d '[{ "key": "name", "value": "Bruce Wayne"}]' http://localhost:3500/v1.0/state/statestore
```

*There will be no return value for this command.*

>[!IMPORTANT]
>Note that the State Management API is based on managing key/value objects. If you're looking for SQL based functionality look into [Dapr bindings](https://docs.dapr.io/developing-applications/building-blocks/bindings/bindings-overview/) in the Dapr docs.

## 3. Get state

Run the following command in the *cURL terminal* to retrieve the state you just saved:

```bash,run
curl http://localhost:3500/v1.0/state/statestore/name
```

The output should be:

```text,nocopy
"Bruce Wayne"
```

## 4. Inspect the state using Redis CLI

Run the following command in the *Redis terminal* to list all the keys in the Redis container:

```bash,run
 keys *
```

The output should be:

```text,nocopy
1) "myapp||name"
```

>[!IMPORTANT]
> Note that the key is prefixed with the `app-id` *myapp*. This is the default behaviour in Dapr. Every application manages their  data via the `app-id` prefix. If you want multiple applications to access the same data you can change this by configuring the state store component, see [Specifying a state prefix strategy](https://docs.dapr.io/developing-applications/building-blocks/state-management/howto-share-state/) in the Dapr Docs.

## 5. Delete state

Run the following command in the *cURL terminal* to delete the key/value pair:

```bash,run
curl -v -X DELETE -H "Content-Type: application/json" http://localhost:3500/v1.0/state/statestore/name
```

## 6. Inspect the state using Redis CLI

Run the following command in the *Redis terminal* to verify the key/value pair is removed from Redis:

```bash,run
 keys *
```

The output should be:

```text,nocopy
(empty array)
```

## 7. Stop the Dapr process

Stop the Dapr sidecar by activating the *Dapr sidecar terminal* and typing `CTRL+C`.

The output should be:

```text,nocopy
terminated signal received: shutting down
✅  Exited Dapr successfully
```

## 8. Inspect the State Store  component file

Dapr knows to use Redis as the default state store when `statestore` is used in the State Mangement API endpoint because Dapr reads a component file that contains this definition. When Dapr is initialized with the CLI, several default component files are placed in the `.dapr/components` folder in the user profile.

Ensure that the Dapr process is stopped and use the *Dapr sidecar terminal* to run the following command to show the content of the default `statestore.yaml` component file in the user profile:

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

>[!IMPORTANT]
>The value of `metadata.name` is `statestore`, this is the same name that is used in the cURL commands to identify this component.
>
> The value of `spec.type` is `state.redis`, and this indicates Redis is used as a state store.
>
> The `metadata` section is specific to each type of component and will have different fields.

Now you know how the Dapr State Management HTTP API can be used to manage key/value data.

Normally you would write an application that uses the Dapr API and not make cURL requests yourself. So let's try running some applications that use the Dapr API in the next assignment.