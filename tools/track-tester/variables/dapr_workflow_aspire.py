"""Shared variables for the dapr-workflow-aspire lab suites.

The learner builds the app from scratch in the workspace folder of the demo repo. TRACKS_SRC_DIR
resolves (in order): the TRACKS_SRC_DIR environment variable if set (CI, and local runs pointing at
an existing checkout), otherwise ~/university-labs expanded to an absolute path (where
ci/setup-dapr-workflow-aspire.sh and the module's sandbox setup clone the demo repo). The pages
write LAB_FOLDER (`/root/university-labs/workflow-aspire`); the suites run their Run blocks with
that path rewritten to WORKSPACE.

The suites run in page order in one job: each page's suite leaves SOLUTION_DIR in that page's end
state, and a suite that finds it missing rebuilds the earlier pages from their assignments.
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_CI = os.path.join(_HERE, "..", "ci")
if _CI not in sys.path:
    sys.path.insert(0, _CI)
from read_pin import read_pin  # noqa: E402

_REPO_ROOT = os.path.normpath(os.path.join(_HERE, "..", "..", ".."))

TRACKS_SRC_DIR = os.environ.get("TRACKS_SRC_DIR") or os.path.expanduser("~/university-labs")
# The folder the pages' Run blocks `cd` to (the Editor folder and the terminals' start folder).
LAB_FOLDER = "/root/university-labs/workflow-aspire"
WORKSPACE = os.path.join(TRACKS_SRC_DIR, "workflow-aspire")
SOLUTION_DIR = os.path.join(WORKSPACE, "MeridianDiagnostics")

# The Engineering API (apphost.cs: .WithHttpEndpoint(port: 5411)) and the Dev Dashboard that the
# AppHost runs as the dev-dashboard resource. The Dev Dashboard only answers a loopback Host header.
APP_URL = "http://localhost:5411"
DEV_DASHBOARD_URL = "http://localhost:9090"

# The single source of the Aspire pin is dapr-workflow-aspire/versions.hcl; the pages repeat it and
# the suites check that they agree.
ASPIRE_CLI_VERSION = read_pin(
    os.path.join(_REPO_ROOT, "dapr-workflow-aspire", "versions.hcl"), "aspire_cli_version"
)

# Page 2's two ,copy blocks, as (anchor unique to the block body, destination relative to
# SOLUTION_DIR, mode) for assignment_blocks.apply_challenge. Every other file is written by a
# heredoc Run block.
MANIFEST_PAGE2 = [
    ("class DiagnosticsWorkflow", "Engineering/DiagnosticsWorkflow.cs", "write"),
    ("class DiagnoseSubsystemActivity", "Engineering/Activities.cs", "write"),
]
