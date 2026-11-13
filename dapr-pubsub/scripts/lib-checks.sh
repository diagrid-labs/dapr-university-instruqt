# shellcheck shell=bash
# Helpers sourced by the dapr-pubsub check scripts. Written for callers running under `set -u`;
# no `set -e` of its own.

# latest_app_log <demo-key> <app-key>
# Echoes the newest app log of <app-key> (order-api, shipping, invoicing or warehouse) for demo
# <demo-key> (1..6) across the dotnet, python and java folders, or nothing (rc 0) when none exists.
# `dapr run -f .` writes <demo dir>/<appDirPath>/.dapr/logs/<appID>_app_<yyyymmddHHMMSS>.log. The
# file name carries the lowercase app ID even in .NET, where the folder is PascalCase.
# Demo 6 reuses the demo 5 apps (its dapr.yaml points appDirPath at the demo 5 app folders), so
# its logs land under the demo 5 folders: demo key 6 searches demo 5. A check for page 6 can
# therefore not tell a demo 5 run from a demo 6 run by folder; it must use order IDs or time.
# Avoids GNU-only flags (find -printf, stat -c) so it also runs on macOS; `ls -t` sorts by mtime.
latest_app_log() {
    local demo="$1" app="$2"
    local base="${TRACKS_SRC_DIR:-$HOME/ai-agent-tracks-instruqt}/pubsub"
    local folder="$demo"
    [ "$demo" = "6" ] && folder=5
    local files=() f lang
    for lang in dotnet python java; do
        for f in "$base/$lang"/[Dd]emo"$folder"-*/*/.dapr/logs/"${app}"_app_*.log; do
            [ -e "$f" ] && files+=("$f")
        done
    done
    [ "${#files[@]}" -eq 0 ] && return 0
    # shellcheck disable=SC2012
    ls -t "${files[@]}" | head -n 1
    return 0
}

# port_answers <port>: 0 when http://localhost:<port>/ connects (any HTTP status), non-zero when
# the connection is refused or times out.
port_answers() {
    curl -s -o /dev/null -m 3 "http://localhost:$1/"
}

# metadata_app_id <dapr-http-port>: echoes the app ID the sidecar on that port reports, or nothing
# (rc 0) when the metadata cannot be read.
metadata_app_id() {
    curl -s -m 5 "http://localhost:$1/v1.0/metadata" 2>/dev/null | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("id", ""))
except ValueError:
    pass' 2>/dev/null
    return 0
}

# metadata_sub_type <dapr-http-port> <topic>: echoes the type (DECLARATIVE, PROGRAMMATIC or
# STREAMING) of the subscription on <topic> in the sidecar's metadata, NONE when there is no such
# subscription, or nothing (rc 0) when the metadata cannot be read.
metadata_sub_type() {
    curl -s -m 5 "http://localhost:$1/v1.0/metadata" 2>/dev/null | python3 -c '
import json, sys
try:
    meta = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
topic = sys.argv[1]
print(next((s.get("type", "") for s in meta.get("subscriptions") or [] if s.get("topic") == topic), "NONE"))' "$2" 2>/dev/null
    return 0
}

# metadata_sub_route <dapr-http-port> <topic>: echoes the first route path (for example /orders/bulk)
# of the subscription on <topic> in the sidecar's metadata, NONE when there is no such subscription,
# or nothing (rc 0) when the metadata cannot be read. The metadata does not show `bulkSubscribe`,
# but the route does tell demos apart that share an app ID and a topic.
metadata_sub_route() {
    curl -s -m 5 "http://localhost:$1/v1.0/metadata" 2>/dev/null | python3 -c '
import json, sys
try:
    meta = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
topic = sys.argv[1]
sub = next((s for s in meta.get("subscriptions") or [] if s.get("topic") == topic), None)
if sub is None:
    print("NONE")
else:
    rules = sub.get("rules") or [{}]
    print(rules[0].get("path", ""))' "$2" 2>/dev/null
    return 0
}
