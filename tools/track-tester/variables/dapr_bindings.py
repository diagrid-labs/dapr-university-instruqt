"""Shared variables for the dapr-bindings track suites.

AI_AGENT_TRACKS_DIR resolves (in order): the AI_AGENT_TRACKS_DIR environment variable
if set (used by CI and by local runs pointing at an existing checkout), otherwise
~/ai-agent-tracks-instruqt expanded to an absolute path (where
ci/setup-dapr-bindings.sh clones the repo).
"""
import os

AI_AGENT_TRACKS_DIR = os.environ.get("AI_AGENT_TRACKS_DIR") or os.path.expanduser(
    "~/ai-agent-tracks-instruqt"
)
