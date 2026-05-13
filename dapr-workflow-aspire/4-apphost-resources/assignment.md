In this challenge you'll wire up the infrastructure that Dapr Workflow and the Diagrid Dev Dashboard need to run. You'll author two Dapr state store component files, make sure they ship to the output directory, and update the AppHost so Aspire orchestrates Valkey, the Dapr sidecar, the dashboard, and the API service together.

There are two Dapr component files required under the AppHost project:

1. A Dapr state store component that is used by Dapr Workflow
2. A Dapr state store component that is used by the Diagrid Dev Dashboard

Both files point to the same state store (Valkey) but require a different value for `redisHost` due to networking.

Ensure that the *Terminal* path is currently in `EnterpriseDiagnostics/`.

## 1. `Resources/dapr/workflow-state.yaml`

Let's create the component file used by Dapr to store workflow state. This will be the location of the file: `Resources/dapr/workflow-state.yaml`.

1. Create the folder using the *Terminal*:

```shell,run,copy
mkdir EnterpriseDiagnostics.AppHost/Resources/dapr
```

2. Create the empty component file using the *Terminal*:

```shell,run,copy
touch EnterpriseDiagnostics.AppHost/Resources/dapr/workflow-state.yaml
```

3. Refresh the *Editor* window to see the new file.

4. Update the content of the empty file using the *Editor* window:

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
      value: "localhost:16379"
    - name: redisPassword
      value: "state-store-123"
    - name: actorStateStore
      value: true
```

## 2. `Resources/dapr/diagrid-dashboard-components/diagrid-dashboard-state.yaml`

The Diagrid Dev Dashboard requires a connection to the statestore that is based on a Dapr component file. The default location for the Diagrid Dev Dashboard Aspire integration is `Resources/dapr/diagrid-dashboard-components` in the AppHost project.

1. Create the folder using the *Terminal*:

```shell,run,copy
mkdir EnterpriseDiagnostics.AppHost/Resources/dapr/diagrid-dashboard-components
```

2. Create the empty component file using the *Terminal*:

```shell,run,copy
touch EnterpriseDiagnostics.AppHost/Resources/dapr/diagrid-dashboard-components/diagrid-dashboard-state.yaml
```

3. Refresh the *Editor* window to see the new file.

4. Copy the following component spec in the empty file using the *Editor* window:

```yaml,copy
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: diagrid-dashboard-store
scopes:
  - diagrid-dashboard
spec:
  type: state.redis
  version: v1
  metadata:
    - name: redisHost
      value: "host.docker.internal:16379"
    - name: redisPassword
      value: "state-store-123"
    - name: actorStateStore
      value: true
```

## 3. Update `EnterpriseDiagnostics.AppHost.csproj`

The two Dapr component files in the Resources folder need to be available when the Aspire solution runs.

Add a `Content` item group so the component files are copied to the output directory. Use the *Editor* window to add the item group to the `EnterpriseDiagnostics.AppHost.csproj` file:

```xml,copy
  <ItemGroup>
    <Content Include="Resources\**\*.*">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
      <Link>Resources\%(RecursiveDir)%(Filename)%(Extension)</Link>
    </Content>
  </ItemGroup>
```

## 4. Replace `AppHost.cs`

Replace the contents of `EnterpriseDiagnostics.AppHost/AppHost.cs` with the following:

```csharp,copy
using System.Reflection;
using CommunityToolkit.Aspire.Hosting.Dapr;
using Diagrid.Aspire.Hosting.Dashboard;

var builder = DistributedApplication.CreateBuilder(args);

builder.AddDapr();

string executingPath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location)
    ?? throw new("Where am I?");

var cachePassword = builder.AddParameter("cache-password", "state-store-123", secret: true);
var cache = builder
    .AddValkey("cache", 16379, cachePassword)
    .WithContainerName("workflow-state")
    .WithDataVolume("workflow-state-data");

var apiService = builder
    .AddProject<Projects.EnterpriseDiagnostics_ApiService>("apiservice")
    .WithHttpsEndpoint(port: 7337, name: "https")
    .WithHttpEndpoint(port: 5411, name: "http")
    .WithDaprSidecar(new DaprSidecarOptions
    {
        LogLevel = "debug",
        ResourcesPaths =
        [
            Path.Join(executingPath, "Resources", "dapr"),
        ],
    });

apiService.WaitFor(cache);
builder.AddDiagridDashboard();

builder.Build().Run();
```

> The explicit `WithHttpsEndpoint` / `WithHttpEndpoint` calls pin the apiservice to fixed ports so the URL stays stable across runs.

## 5. Verify

From the solution root:

```shell,run,copy
dotnet build EnterpriseDiagnostics.sln
```

---

The AppHost now starts Valkey as the workflow state store, runs the API service with a Dapr sidecar that picks up your component files, and exposes the Diagrid Dev Dashboard alongside it. A single `aspire run` brings the full stack up — which is exactly what the next challenge will do.
