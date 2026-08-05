# NOTE: this challenge is interactive. It requires stopping and restarting a
# blocking `dapr run` process around a deliberate crash, which can't be fully
# automated from a single non-interactive script. The manual flow is:
#
#   1. uv run dapr run --app-id langgraph-crash-test --resources-path ./resources -- python crash_test.py
#   2. curl -X POST http://localhost:8001/run -H "Content-Type: application/json" \
#        -d '{"topic": "company gala on March 15"}'
#   3. Wait for the crash (the app process exits).
#   4. Comment out line 30 (`os._exit(1)`) in crash_test.py.
#   5. uv run dapr run --app-id langgraph-crash-test --resources-path ./resources -- python crash_test.py
#
# This scripts that same flow so the Redis keys the check.sh looks for exist afterwards.
cd catalyst-quickstarts/agents/langgraph

uv run dapr run --app-id langgraph-crash-test --resources-path ./resources -- python crash_test.py &

until curl -s http://localhost:8001/docs >/dev/null 2>&1; do
  sleep 1
done

curl -s -X POST http://localhost:8001/run \
  -H "Content-Type: application/json" \
  -d '{"topic": "company gala on March 15"}'

# Wait for the first (crashing) process to exit.
sleep 5

sed -i 's/^\( *\)os\._exit(1)/\1# os._exit(1)/' crash_test.py

uv run dapr run --app-id langgraph-crash-test --resources-path ./resources -- python crash_test.py &
APP_PID=$!

sleep 8
kill "$APP_PID" 2>/dev/null
