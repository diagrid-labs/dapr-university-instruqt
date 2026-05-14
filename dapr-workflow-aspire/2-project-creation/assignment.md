In this challenge you'll lay the foundation for the USS Enterprise diagnostics application. You'll scaffold a new Aspire solution, pin its dashboard to fixed ports so it's reachable in the learning environment, and add the NuGet packages required for Dapr and Dapr Workflow.

## 1. Scaffold the Aspire solution

1. Start by running the following `aspire new` command to scaffold the `aspire-starter` template solution which serves as the basis for the workflow application you're building:

```shell,run
aspire new aspire-starter -n EnterpriseDiagnostics -o EnterpriseDiagnostics --non-interactive --test-framework none
```

Expected output:

```text,nocopy
Searching for available project template versions...
🧊 Getting templates...
📦 Using project templates version: 13.3.2
🚀 Creating new Aspire project...
🔐 Trusting certificates...
⚠️ Developer certificates may not be fully trusted (trust exit code was: PartiallyFailedToTrustTheCertificate).
✅ Project created successfully in /root/dapr-workflow-aspire/EnterpriseDiagnostics.
Detecting agent environments...
✅ Installed aspire skill (.agents/skills/aspire).
✅ Installed aspire skill (~/.agents/skills/aspire).
✅ Installed aspireify skill (.agents/skills/aspireify).
✅ Installed aspireify skill (~/.agents/skills/aspireify).
✅ Agent environment configuration complete.
```

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

1. Remove the `https` profile completely.
2. Update the`http` profile as follows:

```json,copy
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
```

> [!IMPORTANT]
> Use `0.0.0.0` instead of `localhost` and ensure the port numbers match exactly with the above profile, otherwise the Aspire dashboard can't be accessed in the learning environment. Also verify that the `DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS` and `ASPIRE_ALLOW_UNSECURED_TRANSPORT` variables are set to `true`.

## 3. Add the NuGet packages

Now let's install some dependencies the solution requires. You're building a Dapr Workflow solution and this needs: `Dapr.Workflow`, `Dapr.Workflow.Versioning` and `CommunityToolkit.Aspire.Hosting.Dapr`.



1. Use the *Terminal* (ensure you're in `EnterpriseDiagnostics/`) to install all the required packages to the correct projects:

```shell,run,copy
dotnet add EnterpriseDiagnostics.ApiService/EnterpriseDiagnostics.ApiService.csproj package Dapr.Workflow --version 1.17.9
dotnet add EnterpriseDiagnostics.ApiService/EnterpriseDiagnostics.ApiService.csproj package Dapr.Workflow.Versioning --version 1.17.9
dotnet add EnterpriseDiagnostics.AppHost/EnterpriseDiagnostics.AppHost.csproj package CommunityToolkit.Aspire.Hosting.Dapr --version 13.0.0
```

The AppHost project  should have these packages:

```text,nocopy
<PackageReference Include="CommunityToolkit.Aspire.Hosting.Dapr" Version="13.0.0" />
```

The ApiService project  should have these packages:

```text,nocopy
<PackageReference Include="Dapr.Workflow" Version="1.17.9" />
<PackageReference Include="Dapr.Workflow.Versioning" Version="1.17.9" />
<PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="10.0.7" />
```

## 4. Build and Run

1. Run `dotnet build` to verify to solution builds without errors.

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
