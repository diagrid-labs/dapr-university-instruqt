# NOTE: this challenge runs a blocking `dapr run` process in one terminal while
# triggering it from another, which can't be fully automated from a single
# non-interactive script. The manual flow is:
#
#   1. uv run dapr run --app-id schedule-planner --resources-path ./resources -- python main.py
#   2. curl -X POST http://localhost:8005/agent/run -H "Content-Type: application/json" \
#        -d '{"task": "Check if the Grand Ballroom is available on March 15th"}'
#
# This backgrounds the app, triggers it, waits for the reply, then stops it,
# so the Redis keys the check.sh looks for exist afterwards.
source ~/.bashrc
cd catalyst-quickstarts/agents/langgraph

uv run dapr run --app-id schedule-planner --resources-path ./resources -- python main.py &
APP_PID=$!

until curl -s http://localhost:8005/docs >/dev/null 2>&1; do
  sleep 1
done

curl -s -X POST http://localhost:8005/agent/run \
  -H "Content-Type: application/json" \
  -d '{"task": "Check if the Grand Ballroom is available on March 15th"}'

sleep 5
kill "$APP_PID" 2>/dev/null
