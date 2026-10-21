"""Shared variables for the dapr-secrets track suites.

TRACKS_SRC_DIR resolves (in order): the TRACKS_SRC_DIR environment variable if set
(used by CI and by local runs pointing at an existing checkout), otherwise
~/ai-agent-tracks-instruqt expanded to an absolute path (where ci/setup-dapr-secrets.sh
and _setup/sandbox-setup.sh clone the demo repo).

The DENIED_* / MISSING_* values are what the Secrets API returns over HTTP when scoping
refuses a secret (403) versus when a permitted secret is absent from the store (500). They
were confirmed empirically against daprd 1.18.7 and are the single source of truth for
challenge 3's suite, its assignment and every later reference. The error wording is
undocumented and version-sensitive, so a Dapr upgrade that changes it should fail the suite
here rather than silently drift from the assignment.
"""
import os

TRACKS_SRC_DIR = os.environ.get("TRACKS_SRC_DIR") or os.path.expanduser("~/ai-agent-tracks-instruqt")
SECRETS_BASE = os.path.join(TRACKS_SRC_DIR, "secrets")
DEMO1 = "Demo1-ReadSecret"
DEMO2 = "Demo2-Scoping"
DENIED_STATUS = "403"
DENIED_BODY = "ERR_PERMISSION_DENIED"
MISSING_STATUS = "500"
MISSING_BODY = "ERR_SECRET_GET"

# The demo apps do not pass the sidecar's error through. They answer 403 / 500 with the gRPC status
# name in an "error" field. Those strings differ from DENIED_BODY / MISSING_BODY above, and
# ERR_PERMISSION_DENIED contains PERMISSION_DENIED, so each response surface must be asserted
# with its own constant (and compared for equality, not as a substring):
#   raw sidecar : DENIED_STATUS / DENIED_BODY (ERR_PERMISSION_DENIED),
#                 MISSING_STATUS / MISSING_BODY (ERR_SECRET_GET)
#   demo app    : DENIED_STATUS / APP_DENIED_ERROR (PERMISSION_DENIED),
#                 MISSING_STATUS / APP_MISSING_ERROR (INTERNAL)
APP_DENIED_ERROR = "PERMISSION_DENIED"
APP_MISSING_ERROR = "INTERNAL"
