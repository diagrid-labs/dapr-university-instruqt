KEYS=$(docker exec dapr_redis redis-cli keys "*crash-recovery-demo*" 2>/dev/null)

if [ -z "$KEYS" ]; then
    fail-message "No 'crash-recovery-demo' keys found in Redis. Run crash_test.py, trigger it, let it crash, then comment out the os._exit(1) line and restart it."
else
    echo "Durable workflow state found in Redis, crash and recovery proven! 👍"
fi
