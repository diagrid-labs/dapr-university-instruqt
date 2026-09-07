if [ -z "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
    fail-message "Dapr containers are not running. Run 'dapr init' in the Terminal, then click Check again."
else
    echo "Sandbox ready! 👍"
fi
