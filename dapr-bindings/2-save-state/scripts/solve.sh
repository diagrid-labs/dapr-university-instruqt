cd ai-agent-tracks-instruqt/bindings/venue-bookings

uv run dapr run --app-id venue-bookings --resources-path ./resources -- python app.py &
APP_PID=$!

until curl -s http://localhost:8006/bookings >/dev/null 2>&1; do
  sleep 1
done

curl -s -X POST http://localhost:8006/bookings \
  -H "Content-Type: application/json" \
  -d '{"venue": "Grand Ballroom", "event_date": "2026-03-15"}'

sleep 2
kill "$APP_PID" 2>/dev/null
