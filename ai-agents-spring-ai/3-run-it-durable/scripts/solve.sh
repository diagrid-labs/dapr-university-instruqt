# NOTE: assumes challenge 1's login already happened (interactive device-code flow).
cd catalyst-quickstarts/agents/spring-ai/crash-recovery

diagrid project create spring-ai-crash-recovery --enable-managed-workflow --deploy-managed-kv --wait --use
diagrid agent create spring-ai-crash-recovery --wait

diagrid dev run -f dev-spring-ai-crash-recovery.yaml --approve &
APP_PID=$!

until curl -s http://localhost:8080/crash/book?id=healthcheck >/dev/null 2>&1; do
  sleep 2
done

curl -s "http://localhost:8080/crash/book?id=warmup-1&reference=ABC100"

sleep 5
kill "$APP_PID" 2>/dev/null
