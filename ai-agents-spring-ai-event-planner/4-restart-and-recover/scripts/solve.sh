# NOTE: this challenge edits a source file and restarts a long-running dev
# process, which is easiest to script directly rather than simulate manually.
cd catalyst-quickstarts/agents/spring-ai/event-planner

sed -i 's#^\( *\)Runtime\.getRuntime()\.halt(1);#\1// Runtime.getRuntime().halt(1);#' \
  src/main/java/io/diagrid/quickstart/springai/eventplanner/EventPlannerTools.java

diagrid dev run -f dev-spring-ai-event-planner.yaml --approve &
APP_PID=$!

sleep 30
kill "$APP_PID" 2>/dev/null

diagrid project delete spring-ai-quickstart --yes 2>/dev/null || true
