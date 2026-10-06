In this challenge you'll wire up the infrastructure that Dapr Workflow and the Diagrid Dev Dashboard need to run. You'll create a Dapr state store component file (pointing at a Valkey container that Aspire runs for you), make sure it's copied to the output directory on build, and update the AppHost so Aspire orchestrates the Valkey state store, the Dapr sidecar, and the Diagrid Dev Dashboard. This challenge will take about 5 minutes to complete.


## 1. State store component

Dapr Workflow needs a Dapr state store component to persist the workflow state. The component file is located in the AppHost project and points to a Valkey state store. Valkey is an open-source, Redis-compatible key-value store, so the component uses the `state.redis` type. The Valkey container is started by Aspire, which you'll configure in the `AppHost.cs` file later in this challenge.

Ensure that the *Terminal* path is currently in `EnterpriseDiagnostics/`.

### Update the `workflow-state.yaml` component file

Let's create the component file used by Dapr to store workflow state. This will be the location of the file: `EnterpriseDiagnostics.AppHost/Resources/dapr/workflow-state.yaml`.

1. Create the folders and the empty yaml file using the *Terminal*:

```shell,run,copy
mkdir EnterpriseDiagnostics.AppHost/Resources/
mkdir EnterpriseDiagnostics.AppHost/Resources/dapr
touch EnterpriseDiagnostics.AppHost/Resources/dapr/workflow-state.yaml
```

2. Refresh the *Editor* window to see the new file.
3. Update the content of the empty file using the *Editor* window:

```yaml,copy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: workflow-state
spec:
  type: state.redis
  version: v1
  metadata:
    - name: redisHost
      value: localhost:16379
    - name: redisPassword
      value: "state-store-123"
    - name: actorStateStore
      value: "true"
```

## 2. Update `EnterpriseDiagnostics.AppHost.csproj`

The Dapr component file in the Resources folder needs to be available when the Aspire solution runs.

Add a `Content` item group so the component file is copied to the output directory. Use the *Editor* window to add the item group to the `EnterpriseDiagnostics.AppHost.csproj` file:

```xml,copy
  <ItemGroup>
    <Content Include="Resources\**\*.*">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
      <Link>Resources\%(RecursiveDir)%(Filename)%(Extension)</Link>
    </Content>
  </ItemGroup>
```

## 3. Replace `AppHost.cs`

Replace the contents of `EnterpriseDiagnostics.AppHost/AppHost.cs` with the following:

```csharp,copy
using System.Reflection;
using CommunityToolkit.Aspire.Hosting.Dapr;

var builder = DistributedApplication.CreateBuilder(args);

builder.AddDapr();

string executingPath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location)
    ?? throw new("Executing path not found. Where am I?");

// Aspire owns the Valkey container life cycle (started/stopped with the run).
// Port 16379 is pinned to match the hardcoded redisHost in Resources/dapr/workflow-state.yaml.
// The password is supplied as a secret parameter and must match redisPassword in that file.
var statePassword = builder.AddParameter("cache-password", "state-store-123", secret: true);
var stateStore = builder
    .AddValkey("statestore", 16379, statePassword)
    .WithContainerName("enterprise-diagnostics-state")
    .WithDataVolume("enterprise-diagnostics-state-data");

var apiService = builder
    .AddProject<Projects.EnterpriseDiagnostics_ApiService>("apiservice")
    .WithReference(stateStore)
    .WaitFor(stateStore)
    .WithHttpEndpoint(port: 5411, name: "http")
    .WithDaprSidecar(new DaprSidecarOptions
    {
        LogLevel = "debug",
        ResourcesPaths =
        [
            Path.Join(executingPath, "Resources", "dapr"),
        ],
    });

builder.AddExecutable("dapr-dev-dashboard", "diagrid-dev-dashboard", ".",
        "--port", "9090", "--bind", "0.0.0.0", "--no-open")
    .WithHttpEndpoint(port: 9090, isProxied: false);

builder.Build().Run();
```

- `.AddParameter(...)` and `.AddValkey(...)` add a Valkey container as an Aspire resource, so Aspire starts and stops the workflow state store together with the application. The container is pinned to host port `16379` and uses the `state-store-123` password, which both match the `redisHost` and `redisPassword` values in the `workflow-state.yaml` component file. `.WithDataVolume(...)` stores the Valkey data in a Docker volume, so the workflow state survives a restart of the application.
- `.WithReference(stateStore)` and `.WaitFor(stateStore)` make the API service depend on the state store: Aspire only starts the API service, and its Dapr sidecar, once Valkey is running.
- `.WithDaprSidecar(...)` runs a Dapr sidecar next to the API service and loads the component file from the `Resources/dapr` folder.
- `.AddExecutable(...)` starts the Dapr Dev Dashboard executable, which is already installed in this sandbox. It listens on port `9090` and automatically discovers the Dapr apps that Aspire runs, so it doesn't need its own component file. You'll use it in the next challenge to inspect the workflow.

## 4. Verify

Use the *Terminal* to build the solution:

```shell,run,copy
dotnet build
```

---

The AppHost now runs a Valkey state store, the API service with a Dapr sidecar that picks up the Dapr component file pointing at Valkey, and the Diagrid Dev Dashboard. Let's move on to the next challenge to run the solution, start the workflow, and inspect the workflow state using the local Diagrid Dapr Dev Dashboard.
