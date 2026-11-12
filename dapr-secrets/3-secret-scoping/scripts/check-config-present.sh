#!/usr/bin/env bash
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-${HOME:-/root}/ai-agent-tracks-instruqt}"

# Every language ships the same Configuration resource. One of them has to exist.
# The scoping demo folder is Demo2-Scoping in .NET and demo2-scoping in Python and Java.
for demo in dotnet/Demo2-Scoping python/demo2-scoping java/demo2-scoping; do
    if [ -f "$TRACKS_SRC_DIR/secrets/$demo/resources/config-app-b.yaml" ]; then
        echo "config-app-b.yaml is present."
        exit 0
    fi
done
exit 1
