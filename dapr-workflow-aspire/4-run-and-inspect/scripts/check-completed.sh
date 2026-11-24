#!/usr/bin/env bash
# Page 4 check: at least one of the page's diagnostics runs (jump-001, jump-002) has completed.
# It asks the engineering app's status endpoint for each run. When the app does not answer (it is
# stopped, or `aspire run` is not running), it leaves the hint to the api condition, which runs
# page 3's check-api.sh with a message on how to start it again, and passes.
# Read-only (GET only). ENGINEERING_URL overrides the app's address (pytest sets it).
set -u
url="${ENGINEERING_URL:-http://localhost:5411}"
waiting=""
problems=""
found=0
for id in jump-001 jump-002; do
    body="$(curl -s --max-time 10 -w '\n%{http_code}' "$url/status/$id" 2>/dev/null)"
    code="${body##*$'\n'}"
    body="${body%$'\n'*}"
    case "$code" in
        000|"")
            echo "The engineering app does not answer on $url, so the runs can't be read. The api check says how to start it."
            exit 0
            ;;
        404)
            continue
            ;;
        2*)
            found=1
            status="$(printf '%s' "$body" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([A-Za-z]*\)".*/\1/p')"
            case "$status" in
                Completed)
                    echo "The diagnostics run $id has completed."
                    exit 0
                    ;;
                Running|Pending|Suspended)
                    waiting="$waiting $id"
                    echo "The diagnostics run $id is $status."
                    ;;
                *)
                    problems="$problems $id"
                    echo "The diagnostics run $id is ${status:-in an unknown state}."
                    ;;
            esac
            ;;
        *)
            found=1
            problems="$problems $id"
            echo "The status of $id can't be read: the status endpoint returned HTTP $code."
            ;;
    esac
done
if [ -n "$waiting" ]; then
    echo "Its workflow waits 15 seconds before it prioritizes the readings: wait until it completes, then check again."
elif [ "$found" -eq 0 ]; then
    echo "No diagnostics run was found. Start jump-001 with the curl command of section 1."
else
    echo "Start a new run with the curl command of section 1 or 3 and wait until it completes."
fi
exit 1
