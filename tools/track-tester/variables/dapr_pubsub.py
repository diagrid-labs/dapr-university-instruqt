"""Shared variables for the dapr-pubsub track suites.

PUBSUB_DIR resolves (in order): the PUBSUB_DIR environment variable if set (used
by CI and by local runs pointing at an existing checkout), otherwise
~/dapr-pub-sub-deep-dive expanded to an absolute path (where
ci/setup-dapr-pubsub.sh clones the repo).

The track's five challenges each run one DemoN-... folder of that repo, so the
suites build their paths from PUBSUB_DIR rather than hard-coding a location.

TS is the fixed timestamp used in every publish payload in the assignments, so
the suites and the assignments stay identical.
"""
import os

PUBSUB_DIR = os.environ.get("PUBSUB_DIR") or os.path.expanduser("~/dapr-pub-sub-deep-dive")
TS = "2026-01-01T12:00:00Z"
