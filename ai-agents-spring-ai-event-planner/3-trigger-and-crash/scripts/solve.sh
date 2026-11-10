# NOTE: assumes challenge 1's login already happened (interactive device-code flow).
# The /run endpoint always crashes the app on its first call by design, so this
# can't poll /run itself as a readiness check. It waits a fixed amount of time
# for Spring Boot to finish starting instead.
cd catalyst-quickstarts/agents/spring-ai/event-planner

diagrid project create spring-ai-quickstart --enable-managed-workflow --deploy-managed-kv --wait --use
diagrid agent create spring-ai-event-planner --wait

diagrid dev run -f dev-spring-ai-event-planner.yaml --approve &

sleep 30

curl -s -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Find a venue in Austin for a company gala"}'

sleep 3
