KEYS=$(docker exec dapr_redis redis-cli keys "*schedule-planner*" 2>/dev/null)

if [ -z "$KEYS" ]; then
    fail-message "No 'schedule-planner' keys found in Redis. Run the agent with 'dapr run --app-id schedule-planner ...' and trigger it with the curl command first."
else
    echo "Workflow state found in Redis! 👍"
fi
