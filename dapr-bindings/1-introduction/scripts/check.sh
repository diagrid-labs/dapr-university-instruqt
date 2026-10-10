if [ -z "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
    fail-message "Dapr containers not running. Did you run 'dapr init'?"
elif [ -z "$(docker ps -f "name=dapr_postgres" -f "status=running" -q)" ]; then
    fail-message "The dapr_postgres container is not running. Check the sandbox setup or ask for help."
else
    echo "Sandbox ready! 👍"
fi
