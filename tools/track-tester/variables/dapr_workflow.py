"""Shared variables for the dapr-workflow track suites.

QUICKSTARTS_DIR resolves (in order): the QUICKSTARTS_DIR environment variable if
set (used by CI and by local runs pointing at an existing checkout), otherwise
~/quickstarts expanded to an absolute path (where ci/setup-dapr-workflow.sh
clones the repo).

WF_BASE is the tutorials/workflow subtree, which is where the dapr-workflow
track's per-language pattern folders (csharp/java/python) live.
"""
import os

QUICKSTARTS_DIR = os.environ.get("QUICKSTARTS_DIR") or os.path.expanduser("~/quickstarts")
WF_BASE = os.path.join(QUICKSTARTS_DIR, "tutorials", "workflow")
