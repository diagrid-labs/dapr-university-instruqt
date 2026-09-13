# NOTE: this challenge is interactive. It requires killing the app mid-call and
# restarting it around a live 30 second window, which can't be fully automated
# from a single non-interactive script. The manual flow is:
#
#   1. diagrid dev run -f dev-spring-ai-crash-recovery.yaml --approve
#   2. curl "http://localhost:8080/crash/book?id=trip-42&reference=ABC123"   (blocks ~30s)
#   3. During that window, from another terminal: curl -X POST "http://localhost:8080/crash/kill"
#   4. diagrid dev run -f dev-spring-ai-crash-recovery.yaml --approve
#   5. curl "http://localhost:8080/crash/book?id=trip-42&reference=ABC123"   (same confirmation code)
#
# This scripts that same flow.
cd catalyst-quickstarts/agents/spring-ai/crash-recovery

diagrid dev run -f dev-spring-ai-crash-recovery.yaml --approve &

until curl -s "http://localhost:8080/crash/book?id=healthcheck" >/dev/null 2>&1; do
  sleep 2
done

curl -s "http://localhost:8080/crash/book?id=trip-42&reference=ABC123" &

sleep 5
curl -s -X POST "http://localhost:8080/crash/kill"

sleep 3

diagrid dev run -f dev-spring-ai-crash-recovery.yaml --approve &
APP_PID=$!

until curl -s "http://localhost:8080/crash/book?id=healthcheck2" >/dev/null 2>&1; do
  sleep 2
done

curl -s "http://localhost:8080/crash/book?id=trip-42&reference=ABC123"

sleep 5
kill "$APP_PID" 2>/dev/null
