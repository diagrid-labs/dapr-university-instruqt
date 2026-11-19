"""Shared variables for the dapr-pubsub track suites.

TRACKS_SRC_DIR resolves (in order): the TRACKS_SRC_DIR environment variable if set
(used by CI and by local runs pointing at an existing checkout), otherwise
~/university-labs expanded to an absolute path (where ci/setup-dapr-pubsub.sh
and scripts/lab-setup.sh clone the demo repo).
"""
import os

TRACKS_SRC_DIR = os.environ.get("TRACKS_SRC_DIR") or os.path.expanduser("~/university-labs")
PUBSUB_BASE = os.path.join(TRACKS_SRC_DIR, "pubsub")
# Demo folder names per language. They follow each language's own convention: PascalCase for
# .NET (matching the .csproj), kebab-case for Python and Java. Use them as ${DEMO1}[${lang}],
# e.g. ${PUBSUB_BASE}/python/${DEMO1}[python].
DEMO1 = {"dotnet": "Demo1-Subscriptions", "python": "demo1-subscriptions", "java": "demo1-subscriptions"}
DEMO2 = {"dotnet": "Demo2-Streaming", "python": "demo2-streaming", "java": "demo2-streaming"}
DEMO3 = {"dotnet": "Demo3-CloudEvents", "python": "demo3-cloud-events", "java": "demo3-cloud-events"}
DEMO4 = {"dotnet": "Demo4-Bulk", "python": "demo4-bulk", "java": "demo4-bulk"}
DEMO5 = {"dotnet": "Demo5-RoutingDeadLetter", "python": "demo5-routing-dead-letter", "java": "demo5-routing-dead-letter"}
# Demo 6 only holds a dapr.yaml and resources: its apps are the demo 5 apps (appDirPath).
DEMO6 = {"dotnet": "Demo6-SwapProvider", "python": "demo6-swap-provider", "java": "demo6-swap-provider"}
# The app folders inside the demos.
ORDER_API = {"dotnet": "OrderApi", "python": "order-api", "java": "order-api"}
SHIPPING = {"dotnet": "Shipping", "python": "shipping", "java": "shipping"}
INVOICING = {"dotnet": "Invoicing", "python": "invoicing", "java": "invoicing"}
WAREHOUSE = {"dotnet": "Warehouse", "python": "warehouse", "java": "warehouse"}
# The broker image page 6 starts; also baked into the sandbox image (modules/dapr-sandbox).
RABBITMQ_IMAGE = "rabbitmq:4.4.0-management"
