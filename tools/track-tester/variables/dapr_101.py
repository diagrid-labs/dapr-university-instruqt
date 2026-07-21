"""Shared variables for the dapr-101 track suites.

QUICKSTARTS_DIR resolves (in order): the QUICKSTARTS_DIR environment variable if set
(used by CI and by local runs pointing at an existing checkout), otherwise ~/quickstarts
expanded to an absolute path (where ci/setup-dapr-101.sh clones the repo).
"""
import os

QUICKSTARTS_DIR = os.environ.get("QUICKSTARTS_DIR") or os.path.expanduser("~/quickstarts")
SVC_MARKERS = ["Order received", "Order passed"]
PUBSUB_MARKERS = ["Published data", "Subscriber received"]
