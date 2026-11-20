# shellcheck shell=bash
# Library: defines start_postgres and nothing else, so it can be sourced (the module inlines it
# before lab-setup.sh on the VM; ci/setup-dapr-bindings.sh sources it in CI). It uses none of the
# module's helpers (log, die, bounded). Callers own `set -euo pipefail`.
#
# start_postgres <sql-dir>
#   Starts PostgreSQL for the bindings demos as container bindings-postgres, bound to 127.0.0.1:5432
#   only (the demo credentials are dapr/dapr), with <sql-dir> (university-labs/bindings/sql)
#   mounted as the init scripts that create warp_core_readings and comms_log. Removes any existing
#   container first, so it is safe to run again; the demos clear their own tables at startup.
#   On a first start the image runs the init script on a temporary server that listens on the
#   Unix socket only, then shuts it down and starts the final server. A socket query can reach the
#   temporary server just before it stops ("the database system is shutting down"), so this waits
#   up to 60 seconds for the comms_log table over TCP (-h 127.0.0.1, trusted inside the
#   container), which only the final server answers. The image tag must match
#   modules/dapr-sandbox/scripts/prewarm.sh (test_bindings_pins.py).
start_postgres() {
    local sql_dir="$1"
    docker rm -f bindings-postgres >/dev/null 2>&1 || true
    docker run -d --name bindings-postgres -p 127.0.0.1:5432:5432 \
        -e POSTGRES_USER=dapr -e POSTGRES_PASSWORD=dapr -e POSTGRES_DB=dapr \
        -v "$sql_dir:/docker-entrypoint-initdb.d:ro" \
        postgres:18.7 >/dev/null
    local _
    for _ in $(seq 1 60); do
        if docker exec bindings-postgres psql -h 127.0.0.1 -U dapr -d dapr -tAc 'SELECT 1 FROM comms_log' >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    echo "ERROR: Postgres did not create the bindings tables within 60 seconds." >&2
    return 1
}
