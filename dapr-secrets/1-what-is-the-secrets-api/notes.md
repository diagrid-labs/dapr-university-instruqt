Click the *Start* button to setup the sandbox environment for this training, this may take up to 2 minutes. Once the environment ready, click the *Start* button again.

- There are 4 challenges to complete. If your session is idle for more than 10 minutes, the session will stop, and you'll need to restart the track.

- Tracks can be started up to 5 times, and you can select which challenge you want to run via the *Progress* button in the top right, if you don't want to run them all in order.

If you need more information about Dapr during (or after) the challenge, visit the [Dapr Docs](https://docs.dapr.io/developing-applications/building-blocks/secrets/secrets-overview/). If you have any questions or feedback about this track, you can let us know in the *#university* channel of the [Dapr Discord server](https://diagrid.ws/dapr-discord).

---

In this challenge, you'll learn what the Dapr Secrets API is for, and read your first secret from an application.

Applications need secrets such as database passwords and API keys. These often end up in a config file, an environment variable, or even in source control, where anyone with access to the code or the deployment can read them.

The Dapr Secrets API gives your application one place to ask for a secret:

- The application asks the Dapr sidecar for a secret by name. It never needs to know where the secret is stored.
- Which secret store is used is configured in a Dapr component, not in application code.
- Access to secrets can be restricted per application, so an app only sees the secrets it needs.

Dapr supports many secret stores, from a local file to HashiCorp Vault and the secret stores of the major cloud providers.
