#!/usr/bin/env bash
TRACKS_SRC_DIR="${TRACKS_SRC_DIR:-${HOME:-/root}/ai-agent-tracks-instruqt}"

# Every language ships the same Configuration resource. One of them has to exist.
for lang in dotnet python java; do
    if [ -f "$TRACKS_SRC_DIR/secrets/$lang/Demo2-Scoping/resources/config-app-b.yaml" ]; then
        echo "config-app-b.yaml is present."
        exit 0
    fi
done
exit 1
