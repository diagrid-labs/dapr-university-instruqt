if ! diagrid project list 2>/dev/null | grep -q "spring-ai-crash-recovery"; then
    fail-message "No 'spring-ai-crash-recovery' Catalyst project found. Run 'diagrid project create spring-ai-crash-recovery --enable-managed-workflow --deploy-managed-kv --wait --use' first."
elif ! diagrid agent list 2>/dev/null | grep -q "spring-ai-crash-recovery"; then
    fail-message "No 'spring-ai-crash-recovery' agent found. Run 'diagrid agent create spring-ai-crash-recovery --wait'."
else
    echo "Catalyst project and agent are set up! 👍"
fi
