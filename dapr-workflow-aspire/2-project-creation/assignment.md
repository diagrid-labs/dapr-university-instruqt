In this challenge you'll lay the foundation for the USS Enterprise diagnostics application. You'll scaffold a new Aspire solution, pin its dashboard to fixed ports so it's reachable in the learning environment, and add the NuGet packages required for Dapr and Dapr Workflow. This first challenge will take about 5 minutes to complete.

## 1. Scaffold the Aspire solution

1. Start by running the following `dotnet new` command to scaffold the `aspire-starter` template solution which serves as the basis for the workflow application you're building:

```shell,run
dotnet new aspire-starter -n EnterpriseDiagnostics -o EnterpriseDiagnostics
```

The output contains information on the project creation and restoring dependencies. Do not upgrade to the latest version of Aspire since that does not work in this sandbox environment yet.

> [!IMPORTANT]
> Refresh the Editor window using the circular arrow. It should show the EnterpriseDiagnostics solution now.

>[!NOTE]
> The starter template also generates an `EnterpriseDiagnostics.Web` Blazor project. We won't use it in this learning track — you can ignore it and leave it in place.

2. Move into the solution folder for the remaining commands, use the *Terminal* and run:

```shell,run,copy
cd EnterpriseDiagnostics
```

## 2 Update the AppHost launch URLs

Open the `launchSettings.json` file located in `EnterpriseDiagnostics.AppHost/Properties/`.

Replace the entire contents of the file with this json:

```json,copy
{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
    "commandName": "Project",
    "dotnetRunMessages": true,
    "launchBrowser": true,
    "applicationUrl": "http://0.0.0.0:17000",
    "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "DOTNET_ENVIRONMENT": "Development",
        "ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL": "http://0.0.0.0:17001",
        "ASPIRE_RESOURCE_SERVICE_ENDPOINT_URL": "http://0.0.0.0:17003",
        "DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS": true,
        "ASPIRE_ALLOW_UNSECURED_TRANSPORT": true
      }
    }
  }
}
```

> [!IMPORTANT]
> The JSON file uses `0.0.0.0` instead of `localhost`, specific port numbers and environment variables to ensure that the Aspire dashboard can be accessed in this learning environment.

## 3. Add the NuGet packages

Now let's install some dependencies the solution requires. You're building a Dapr Workflow solution and this needs: `Dapr.Workflow`, `Dapr.Workflow.Versioning` and `CommunityToolkit.Aspire.Hosting.Dapr`.

1. Use the *Terminal* (ensure you're in `EnterpriseDiagnostics/`) to install all the required packages to the correct projects:

```shell,run,copy
dotnet add EnterpriseDiagnostics.ApiService/EnterpriseDiagnostics.ApiService.csproj package Dapr.Workflow --version 1.18.4
dotnet add EnterpriseDiagnostics.ApiService/EnterpriseDiagnostics.ApiService.csproj package Dapr.Workflow.Versioning --version 1.18.4
dotnet add EnterpriseDiagnostics.AppHost/EnterpriseDiagnostics.AppHost.csproj package CommunityToolkit.Aspire.Hosting.Dapr --version 13.0.0
```

The AppHost project  should have these packages:

```text,nocopy
<PackageReference Include="CommunityToolkit.Aspire.Hosting.Dapr" Version="13.0.0" />
```

The ApiService project  should have these packages:

```text,nocopy
<PackageReference Include="Dapr.Workflow" Version="1.18.4" />
<PackageReference Include="Dapr.Workflow.Versioning" Version="1.18.4" />
<PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="10.0.7" />
```

## 4. Build and Run

1. Run `dotnet build` to verify that the solution builds without errors.

```shell,run,copy
dotnet build
```

2. Start Aspire and check if the Aspire dashboard is available in the *Aspire* tab (next to the *Editor* tab) and verify the resources are in *Running* state.

```shell,run,copy
aspire run
```

> [!NOTE]
> Don't click on the resource URLs in the Aspire dashboard, those will open in a tab outside the learning sandbox and won't work.

3. Use `CTRL+C` in the *Terminal* window to stop the Aspire solution.

---

Great! You've added the Dapr Workflow dependencies to the new Aspire solution. In the next challenge, you'll add code for models, the workflow and the activities.
