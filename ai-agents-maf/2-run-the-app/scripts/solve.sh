# NOTE: a real OpenAI API key is required for the agents to work end-to-end.
# This solve script creates the files with a placeholder key so the deterministic
# checks pass; replace the key value to actually run the workflow.
cd ai-agent-tracks-instruqt/MAF/PrDigest

cp -n PrDigest.AppHost/secrets.example.json PrDigest.AppHost/secrets.json
cat > PrDigest.AppHost/secrets.json <<'EOF'
{
  "openai-api-key": "sk-replace-with-your-key"
}
EOF

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
