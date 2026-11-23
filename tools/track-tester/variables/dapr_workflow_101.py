"""Shared variables for the dapr-workflow-101 track suites.

TRACKS_SRC_DIR resolves (in order): the TRACKS_SRC_DIR environment variable if set
(used by CI and by local runs pointing at an existing checkout), otherwise
~/university-labs expanded to an absolute path (where ci/setup-dapr-workflow-101.sh
and the module's sandbox setup clone the demo repo).
"""
import os

TRACKS_SRC_DIR = os.environ.get("TRACKS_SRC_DIR") or os.path.expanduser("~/university-labs")
WF101_BASE = os.path.join(TRACKS_SRC_DIR, "workflow")
# Every demo runs the same app (ID engineering) on the same ports in every language.
APP_URL = "http://localhost:5301"
DAPR_HTTP_PORT = 3530
# Demo folders per language, relative to WF101_BASE. They follow each language's own convention:
# PascalCase for .NET (matching the .csproj), kebab-case for Python, Java and TypeScript. Use them
# as ${DEMO1}[${lang}], e.g. ${WF101_BASE}/${DEMO1}[python].
DEMO1 = {
    "dotnet": "dotnet/Demo1-DurableExecution",
    "python": "python/demo1-durable-execution",
    "java": "java/demo1-durable-execution",
    "typescript": "typescript/demo1-durable-execution",
}
DEMO2 = {
    "dotnet": "dotnet/Demo2-TaskChaining",
    "python": "python/demo2-task-chaining",
    "java": "java/demo2-task-chaining",
    "typescript": "typescript/demo2-task-chaining",
}
DEMO3 = {
    "dotnet": "dotnet/Demo3-FanOutFanIn",
    "python": "python/demo3-fan-out-fan-in",
    "java": "java/demo3-fan-out-fan-in",
    "typescript": "typescript/demo3-fan-out-fan-in",
}
DEMO4 = {
    "dotnet": "dotnet/Demo4-Monitor",
    "python": "python/demo4-monitor",
    "java": "java/demo4-monitor",
    "typescript": "typescript/demo4-monitor",
}
DEMO5 = {
    "dotnet": "dotnet/Demo5-HumanInTheLoop",
    "python": "python/demo5-human-in-the-loop",
    "java": "java/demo5-human-in-the-loop",
    "typescript": "typescript/demo5-human-in-the-loop",
}
DEMO6 = {
    "dotnet": "dotnet/Demo6-Management",
    "python": "python/demo6-management",
    "java": "java/demo6-management",
    "typescript": "typescript/demo6-management",
}
