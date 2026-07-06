 The Dapr CLI is used during local development to:
 - Run your applications with a Dapr sidecar.
 - Review the Dapr sidecar logs.
 - List running services.

**In this challenge you'll download the Dapr CLI, initialize Dapr, and verify the installation.** This hands-on challenge takes about 5 minutes to complete.

> [!IMPORTANT]
> You'll work with read-only *language tabs* that hold the sample code, and one or more *Terminal* windows where you run commands, all inside this sandbox. If a tab or terminal isn't available — or you hit any blocking issue during this course — send me [an email](mailto:marc@diagrid.io) and we'll figure it out together.

## 1. Download the Dapr CLI

Since this is a Linux environment, download the Dapr CLI using wget:

```bash,run
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
```

## 2. Verify the installation

To verify that the Dapr CLI is installed run:

```bash,run
dapr -h
```

The expected output should be:

```text,nocopy
          __
     ____/ /___ _____  _____
    / __  / __ '/ __ \/ ___/
   / /_/ / /_/ / /_/ / /
   \__,_/\__,_/ .___/_/
             /_/

===============================
Distributed Application Runtime

Usage:
  dapr [flags]
  dapr [command]
...
```

As you can see in the output, the Dapr CLI can be used for many things, some commands are only available in self-hosted mode, and others for running Dapr with Kubernetes. You can read more about the Dapr CLI commands in the [Dapr docs](https://docs.dapr.io/reference/cli/). In this assignment you will use `init` and `version` only. In the next assignments you will frequently use the `run` command.

## 3. Initialize Dapr

Dapr runs as a sidecar alongside your application. In self-hosted mode, this means Dapr runs as a process on your local machine. At the moment, you have the Dapr CLI installed, but this is not the Dapr sidecar that runs next to your application. This needs to be installed locally using the Dapr CLI via `dapr init`. By initializing Dapr, you:
- Fetch and install the Dapr sidecar binaries locally.
- Create a development environment that streamlines application development with Dapr.

Dapr initialization includes:
- Running a Redis container instance to be used as a local state store and message broker.
- Running a Zipkin container instance for observability.
- Creating a default components folder with component definitions for the above.
- Running a Dapr placement service container instance for local actor support.
- Running a Dapr scheduler service container instance for job scheduling.

Initialize Dapr with the CLI:

```bash,run
dapr init
```

This will take about 30 seconds depending on download speed.

## 4. Verify the Dapr version

To verify the installation of both the Dapr CLI and the Dapr runtime run:

```bash,run
dapr --version
```

The expected output should be:

```text,nocopy
CLI version: [[ Instruqt-Var key="DAPR_CLI_VERSION" hostname="dapr-uni-vm" ]]
Runtime version: [[ Instruqt-Var key="DAPR_RUNTIME_VERSION" hostname="dapr-uni-vm" ]]
```

## 5. Verify the containers

Verify that the Dapr containers are running:

```bash,run
docker ps --format {{.Names}}
```

The expected output should be 4 running containers:
- `dapr_placement`: Used to manage the location for Dapr Actors.
- `dapr_scheduler`: Used by Dapr Actors & the Jobs API.
- `dapr_redis`: The default State Management & Pub/Sub component when running Dapr in self-hosted mode.
- `dapr_zipkin`:  The default tracing dashboard when running Dapr in self-hosted mode.

> [!IMPORTANT]
> Click the *Check* button to verify the containers are running before you can continue.

You've now downloaded and initialized Dapr in self-hosted mode. The local environment is now ready for development! Let's continue and try the some Dapr APIs in the next challenge.
