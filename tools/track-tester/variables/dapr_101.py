"""Shared variables for the dapr-101 track suites.

TRACKS_SRC_DIR resolves (in order): the TRACKS_SRC_DIR environment variable if set
(used by CI and by local runs pointing at an existing checkout), otherwise
~/ai-agent-tracks-instruqt expanded to an absolute path (where ci/setup-dapr-101.sh
and scripts/lab-setup.sh clone the demo repo).
"""
import os

TRACKS_SRC_DIR = os.environ.get("TRACKS_SRC_DIR") or os.path.expanduser("~/ai-agent-tracks-instruqt")
DAPR101_BASE = os.path.join(TRACKS_SRC_DIR, "dapr-101")
# Demo folder names per language, used as ${SVC_DEMO}[${lang}], e.g. ${DAPR101_BASE}/python/${SVC_DEMO}[python].
# PascalCase for .NET (matching the .csproj), kebab-case for the others.
SVC_DEMO = {"dotnet": "ServiceInvocation", "python": "service-invocation", "java": "service-invocation", "javascript": "service-invocation"}
PUBSUB_DEMO = {"dotnet": "PubSub", "python": "pub-sub", "java": "pub-sub", "javascript": "pub-sub"}
# Log markers the apps print once the flow works.
SVC_MARKERS = ["Order received", "Order passed"]
PUBSUB_MARKERS = ["Published data", "Subscriber received"]
