In this challenge you'll configure your OpenAI API key, make the Aspire dashboard reachable in this sandbox, and start the full PrDigest stack with a single `aspire run`. It will take about 5 minutes.

This challenge uses two terminals:

- *Aspire Terminal* — for running the long-lived `aspire run` command.
- *Curl Terminal* — used in the next challenges.

> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

All terminal paths start in `MAF/PrDigest`, which contains the `PrDigest.sln` solution.

## 1. Add your OpenAI API key

The agents reach OpenAI through the Dapr conversation component, which reads the key from a local secret store (`PrDigest.AppHost/secrets.json`). That file is git-ignored and not part of the clone, so create it from the template. In the *Aspire Terminal*:

```shell,run,copy
cp PrDigest.AppHost/secrets.example.json PrDigest.AppHost/secrets.json
```

Open `PrDigest.AppHost/secrets.json` in the *Editor* and paste your key so it looks like this:

```json,nocopy
{
  "openai-api-key": "sk-...your-key..."
}
```

Save the file.

## 2. Make the Aspire dashboard reachable

The default Aspire launch profile binds the dashboard to `localhost` on random ports, which this sandbox can't expose. Pin it to a fixed, anonymous HTTP endpoint by replacing the AppHost launch settings. Run this in the *Aspire Terminal*:

```shell,run,copy
cat > PrDigest.AppHost/Properties/launchSettings.json <<'EOF'
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
EOF
```

> [!IMPORTANT]
> The dashboard uses `0.0.0.0` and fixed ports so it's reachable in the *Aspire* tab. The API service keeps its own fixed port (`5090`), pinned in the AppHost code.

## 3. Run the application

Set a known output directory (you'll read generated files from it in later challenges) and start Aspire. Run both in the *Aspire Terminal*:

```shell,run,copy
export DIGEST_OUTPUT_DIR=/root/digest-out
aspire run
```

Aspire starts the API service, its Dapr sidecar, and a Valkey state store, then prints a dashboard URL.

Switch to the *Aspire* tab and wait until all resources show **Running**:

- `statestore` — the Valkey container that durably stores workflow state.
- `pr-digest` — the API service hosting the workflow and the MAF agents.
- `pr-digest-dapr-sidecar` — the Dapr sidecar.

> [!NOTE]
> Don't click the resource URLs inside the Aspire dashboard — they open outside the sandbox and won't work. Navigate using the dashboard's own views instead.

> [!IMPORTANT]
> Leave `aspire run` running and click the *Check* button.

---

The application is up and the agents can reach OpenAI. In the next challenge you'll trigger the workflow and read the ranked pull-request digest the agents produce.
