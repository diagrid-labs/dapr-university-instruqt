# shellcheck shell=bash
# Helpers sourced by the dapr-pubsub check and solve scripts. Written for callers running under
# `set -u`; no `set -e` of its own. Only function definitions: lab_startup_script (versions.hcl)
# puts this file in front of lab-setup.sh, which writes every function below to
# /usr/local/lib/dapr-pubsub/lib-checks.sh, because the lab's own files are not on the VM. A new
# helper must be added to the list in lab-setup.sh (test_pubsub_lib_checks.py checks it).

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
    local base="${TRACKS_SRC_DIR:-${HOME:-/root}/ai-agent-tracks-instruqt}/pubsub"
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

# metadata_component_type <dapr-http-port> <component-name>: echoes the type (for example
# pubsub.rabbitmq or pubsub.redis) of the component with that name in the sidecar's metadata, NONE
# when there is no such component, or nothing (rc 0) when the metadata cannot be read.
metadata_component_type() {
    curl -s -m 5 "http://localhost:$1/v1.0/metadata" 2>/dev/null | python3 -c '
import json, sys
try:
    meta = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
name = sys.argv[1]
print(next((c.get("type", "") for c in meta.get("components") or [] if c.get("name") == name), "NONE"))' "$2" 2>/dev/null
    return 0
}

# stop_all_demos [<wait-seconds>]: stops every pubsub demo (any demo, any language) with
# `dapr stop -f .`, however it was started, then waits up to <wait-seconds> (default 30) until
# nothing answers on port 5101 any more. Always rc 0.
stop_all_demos() {
    local base="${TRACKS_SRC_DIR:-${HOME:-/root}/ai-agent-tracks-instruqt}/pubsub" dir
    for dir in "$base"/dotnet/Demo*-* "$base"/python/demo*-* "$base"/java/demo*-*; do
        [ -f "$dir/dapr.yaml" ] && { (cd "$dir" && dapr stop -f . >/dev/null 2>&1) || true; }
    done
    for _ in $(seq 1 "${1:-30}"); do
        curl -s -o /dev/null -m 2 http://localhost:5101/ || break
        sleep 1
    done
    return 0
}

# start_demo_detached <demo-dir> <log-file>: starts `dapr run -f .` in <demo-dir> in the background,
# detached from the caller (own session where setsid exists, no stdin), output to <log-file>.
start_demo_detached() {
    (
        cd "$1" || exit 1
        if command -v setsid >/dev/null 2>&1; then
            setsid nohup dapr run -f . </dev/null >"$2" 2>&1 &
        else
            nohup dapr run -f . </dev/null >"$2" 2>&1 &
        fi
    )
}
