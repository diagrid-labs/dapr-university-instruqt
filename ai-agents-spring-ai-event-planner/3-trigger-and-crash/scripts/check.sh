if ! diagrid project list 2>/dev/null | grep -q "spring-ai-quickstart"; then
    fail-message "No 'spring-ai-quickstart' Catalyst project found. Run 'diagrid project create spring-ai-quickstart --enable-managed-workflow --deploy-managed-kv --wait --use' first."
elif ! diagrid agent list 2>/dev/null | grep -q "spring-ai-event-planner"; then
    fail-message "No 'spring-ai-event-planner' agent found. Run 'diagrid agent create spring-ai-event-planner --wait'."
else
    echo "Catalyst project and agent are set up! 👍"
fi
