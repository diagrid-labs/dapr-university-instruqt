if [ -n "$(docker ps -f "name=dapr_placement" -f "status=running" -q )" ] && [ -n "$(docker ps -f "name=dapr_scheduler" -f "status=running" -q )" ] && [ -n "$(docker ps -f "name=dapr_redis" -f "status=running" -q )"  ] && [ -n "$(docker ps -f "name=dapr_zipkin" -f "status=running" -q )" ];
then
    echo "The Dapr containers are running! 👍"
else
    fail-message "The Dapr containers not yet running! Did you run 'dapr init'?"
fi