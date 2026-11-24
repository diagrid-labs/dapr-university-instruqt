# Create the solution

In this lab, you'll create an Aspire solution and add the API project that will run the workflow. This hands-on lab takes about 7 minutes to complete.

## 1. The pre-jump diagnostics

This track tells one story. Before every warp jump, the **engineering** console of the starship *ISV Meridian* runs pre-jump diagnostics: it checks the warp core, life support and shields in parallel, decides how urgent the findings are, and notifies the bridge when something needs attention. In the 4 labs of this track you'll build that diagnostics app from an empty folder, as a Dapr workflow that runs with Aspire:

1. In this lab you create the Aspire solution and the `Engineering` project.
2. In the next lab you write the workflow and its activities.
3. Then you describe the app in the Aspire AppHost and start everything with one command.
4. In the last lab you run the diagnostics, inspect them, and restart the app in the middle of a run.

[Aspire](https://aspire.dev) runs a distributed app on your machine from one file of C#, the *AppHost*. The AppHost lists the app's resources: projects, containers, executables and, with the Dapr integration, Dapr sidecars and components. `aspire run` starts them all and opens a dashboard that shows each resource, its logs and its traces.

This is what you'll have at the end of the track:

![The Aspire AppHost, apphost.cs, runs the engineering app with its Dapr sidecar, the Dev Dashboard and the Aspire dashboard. The sidecar saves the workflow history through the statestore component in the dapr_redis container, and the Dev Dashboard reads it from there.](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow-aspire/1-create-the-solution/images/architecture.png?raw=true)

- `apphost.cs` is the AppHost. It starts the `engineering` app, its Dapr sidecar and the Dev Dashboard.
- The `statestore` component points the sidecar at the Redis container `dapr_redis`, which `dapr init` started in this sandbox. The sidecar saves the workflow history there.
- You look at the running app in two places: the **Aspire** tab shows the resources and their logs, and the **Dev Dashboard** tab shows the workflows and their history. Both tabs stay empty until you start the app in lab 3.

This track focuses on Aspire. If workflows and activities are new to you, take the [Dapr Workflow 101](https://www.diagrid.io/university) track first: it covers the concepts, such as durable execution and replay, in more depth.

## 2. Create the Aspire solution

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

Use the **Aspire CLI** window to go to the `workflow-aspire` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

```bash,run
cd /root/university-labs/workflow-aspire
```

The `workflow-aspire` folder is open in the **Editor** tab. It only holds a `README.md` for now.

Use the **Aspire CLI** window to check that the Aspire CLI is installed:

```bash,run
aspire --version
```

Expected output (the part after the `+` is the build's commit):

```text,nocopy
17.0.0+2d325b13709752ba6d9a943635c5e2940a2530c0
```

Use the **Aspire CLI** window to create the solution from the `aspire-empty` template:

```bash,run
[ -d MeridianDiagnostics ] || aspire new aspire-empty --version 17.0.0 --name MeridianDiagnostics --output MeridianDiagnostics --non-interactive --agents none --nologo
```

`--version 17.0.0` takes the template that matches the CLI, and `--non-interactive --agents none` answers the questions the CLI would otherwise ask. The `[ -d MeridianDiagnostics ] ||` in front runs `aspire new` only when the folder doesn't exist yet, so you can run the block again without an error.

The template creates the `MeridianDiagnostics` folder with these files:

```text,nocopy
MeridianDiagnostics/
├── .vscode/extensions.json
├── apphost.cs
├── apphost.run.json
└── aspire.config.json
```

There is no project file for the AppHost: `apphost.cs` is a single-file C# app, which .NET 10 runs without a `.csproj`. You'll look at it in section 5.

## 3. Add the Engineering project

The engineering console is an ASP.NET Core web API, `Engineering`. It will host the workflow and have two endpoints: one to start a diagnostics run and one to read its status.

Use the **Aspire CLI** window to create the project inside the solution folder:

```bash,run
[ -d MeridianDiagnostics/Engineering ] || dotnet new web -n Engineering -o MeridianDiagnostics/Engineering
```

`dotnet new web` creates an empty web app. As with `aspire new`, the `[ -d ... ] ||` guard skips it when the folder already exists.

Use the **Aspire CLI** window to add the Dapr Workflow package to the project:

```bash,run
dotnet add MeridianDiagnostics/Engineering package Dapr.Workflow --version 1.19.1
```

`Dapr.Workflow` holds the base classes for workflows and activities, the workflow runtime that runs them in your app, and the client that starts workflows and reads their status. The app talks to its Dapr sidecar through this package; the sidecar schedules the activities and stores the history.

Open `MeridianDiagnostics/Engineering/Engineering.csproj` in the **Editor** tab. It now has the package reference:

```xml,nocopy
<ItemGroup>
  <PackageReference Include="Dapr.Workflow" Version="1.19.1" />
</ItemGroup>
```

## 4. Open the dashboard to the sandbox

`aspire run` reads its settings from `apphost.run.json`. The file the template created puts the Aspire dashboard on a random `localhost` port and asks for a login token. That works on your own machine, but not here: the **Aspire** tab reaches the dashboard from outside the sandbox's VM.

Use the **Aspire CLI** window to replace `apphost.run.json` with a profile for this sandbox:

```bash,run
cat > MeridianDiagnostics/apphost.run.json <<'EOF'
{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": false,
      "applicationUrl": "http://0.0.0.0:17000",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "DOTNET_ENVIRONMENT": "Development",
        "ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL": "http://localhost:17001",
        "ASPIRE_RESOURCE_SERVICE_ENDPOINT_URL": "http://localhost:17003",
        "ASPIRE_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS": "true",
        "ASPIRE_ALLOW_UNSECURED_TRANSPORT": "true"
      }
    }
  }
}
EOF
```

The command writes the whole file, so running it again gives the same result. The `http` profile sets three things:

- **Where the dashboard listens.** `applicationUrl` is the dashboard's address. `0.0.0.0` means every network interface of the VM, so the **Aspire** tab can reach the dashboard on port 17000. With `localhost`, it would only accept connections from inside the VM.
- **Where the dashboard gets its data.** The resources send their logs and traces to the OTLP endpoint (port 17001), and the dashboard reads the list of resources from the AppHost's resource service (port 17003). Only the dashboard and the AppHost use these two endpoints, so they stay on `localhost`. The resource service has to: Aspire stops with an error when `ASPIRE_RESOURCE_SERVICE_ENDPOINT_URL` is not a loopback address.
- **No login and no HTTPS.** `ASPIRE_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS` opens the dashboard without the login token, and `ASPIRE_ALLOW_UNSECURED_TRANSPORT` allows plain HTTP. That's fine in a sandbox only you use; keep the defaults on a shared machine. `launchBrowser` is off because the sandbox has no browser of its own.

## 5. A first look at apphost.cs

Open `MeridianDiagnostics/apphost.cs` in the **Editor** tab. This is the AppHost the template created:

```csharp,nocopy
#:package Aspire.Hosting.AppHost@17.0.0
#:package Aspire.Hosting.Dotnet@17.0.0

var builder = DistributedApplication.CreateBuilder(args);

builder.Build().Run();
```

- The `#:package` lines are how a single-file C# app references NuGet packages, instead of a `.csproj`. Both packages are at 17.0.0, the same version as the CLI.
- `DistributedApplication.CreateBuilder(args)` creates the builder that you add resources to.
- `builder.Build().Run()` starts every resource and the dashboard, and keeps running until you stop it.

There are no resources yet, so `aspire run` would only start an empty dashboard. In lab 3 you'll add the `statestore` component, the `engineering` project with its Dapr sidecar, and the Dev Dashboard. `aspire.config.json` tells the CLI that `apphost.cs` is the AppHost, so `aspire run` finds it.

## 6. Check your work

The check below looks for `apphost.cs`, the `Engineering` project with its `Dapr.Workflow` package, and the dashboard address in `apphost.run.json`. If something is missing, the message names the section to redo. The next labs build on this solution, so make sure the check passes before you continue.

<instruqt-task id="create_solution"></instruqt-task>

---

You created the Aspire solution, added the `Engineering` project with the Dapr Workflow package, and opened the Aspire dashboard to the sandbox.

## What's next?

In the next lab you'll write the diagnostics workflow and its three activities, and register them in `Engineering`.
