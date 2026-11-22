"""Shared variables for the dapr-bindings track suites.

TRACKS_SRC_DIR resolves (in order): the TRACKS_SRC_DIR environment variable if set
(used by CI and by local runs pointing at an existing checkout), otherwise
~/university-labs expanded to an absolute path (where ci/setup-dapr-bindings.sh
and the module's sandbox setup clone the demo repo).
"""
import os

TRACKS_SRC_DIR = os.environ.get("TRACKS_SRC_DIR") or os.path.expanduser("~/university-labs")
BINDINGS_BASE = os.path.join(TRACKS_SRC_DIR, "bindings")
# Demo folder names per language. They follow each language's own convention: PascalCase for
# .NET (matching the .csproj), kebab-case for Python and Java. Use them as ${DEMO1}[${lang}],
# e.g. ${BINDINGS_BASE}/python/${DEMO1}[python].
DEMO1 = {"dotnet": "Demo1-CronTrigger", "python": "demo1-cron-trigger", "java": "demo1-cron-trigger"}
DEMO2 = {"dotnet": "Demo2-PostgresOutput", "python": "demo2-postgres-output", "java": "demo2-postgres-output"}
DEMO3 = {"dotnet": "Demo3-StateVsBinding", "python": "demo3-state-vs-binding", "java": "demo3-state-vs-binding"}
DEMO4 = {"dotnet": "Demo4-SubspaceBeacon", "python": "demo4-subspace-beacon", "java": "demo4-subspace-beacon"}
# The app folders inside the demos. Every demo has engineering; demo 4 adds subspace-beacon.
ENGINEERING = {"dotnet": "Engineering", "python": "engineering", "java": "engineering"}
SUBSPACE_BEACON = {"dotnet": "SubspaceBeacon", "python": "subspace-beacon", "java": "subspace-beacon"}
# The database the lab starts at boot (dapr-bindings/scripts/start-postgres.sh); the image is
# also baked into the sandbox image (modules/dapr-sandbox).
POSTGRES_IMAGE = "postgres:18.7"
POSTGRES_CONTAINER = "bindings-postgres"
# Non-interactive psql, as the pages run it: append -c "<sql>".
PSQL = "docker exec bindings-postgres psql -U dapr -d dapr"
