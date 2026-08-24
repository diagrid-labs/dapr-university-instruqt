"""Variables and block->file manifests for the dapr-workflow-aspire suite.

Each manifest entry is (anchor, dest, mode):
  - anchor: a substring unique to the assignment's ,copy block body
  - dest:   path relative to the EnterpriseDiagnostics solution root
  - mode:   "write" (whole file) or "insert_before:<marker>" (splice into a file)
"""

APISERVICE_URL = "http://localhost:5411/"
STATUS_URL = "http://localhost:5411/status/mission-001"
EXPECTED_STARDATE = '"starDate":"41153.7"'

MANIFEST_CH2 = [
    (
        '"$schema": "https://json.schemastore.org/launchsettings.json"',
        "EnterpriseDiagnostics.AppHost/Properties/launchSettings.json",
        "write",
    ),
]

MANIFEST_CH3 = [
    ("class DiagnoseSubsystemActivity",
     "EnterpriseDiagnostics.ApiService/Activities/DiagnoseSubsystemActivity.cs", "write"),
    ("class NotifyBridgeActivity",
     "EnterpriseDiagnostics.ApiService/Activities/NotifyBridgeActivity.cs", "write"),
    ("class PrioritizeDiagnosticsActivity",
     "EnterpriseDiagnostics.ApiService/Activities/PrioritizeDiagnosticsActivity.cs", "write"),
    ("namespace EnterpriseDiagnostics.Models",
     "EnterpriseDiagnostics.ApiService/Models/Models.cs", "write"),
    ("class EnterpriseDiagnosticsWorkflow",
     "EnterpriseDiagnostics.ApiService/Workflows/EnterpriseDiagnosticsWorkflow.cs", "write"),
    ("builder.Services.AddDaprWorkflow",
     "EnterpriseDiagnostics.ApiService/Program.cs", "write"),
]

MANIFEST_CH4 = [
    ("name: workflow-state",
     "EnterpriseDiagnostics.AppHost/Resources/dapr/workflow-state.yaml", "write"),
    ("name: diagrid-dashboard-store",
     "EnterpriseDiagnostics.AppHost/Resources/dapr/diagrid-dashboard-components/diagrid-dashboard-state.yaml", "write"),
    ("<Content Include=\"Resources",
     "EnterpriseDiagnostics.AppHost/EnterpriseDiagnostics.AppHost.csproj", "insert_before:</Project>"),
    ("using CommunityToolkit.Aspire.Hosting.Dapr",
     "EnterpriseDiagnostics.AppHost/AppHost.cs", "write"),
]
