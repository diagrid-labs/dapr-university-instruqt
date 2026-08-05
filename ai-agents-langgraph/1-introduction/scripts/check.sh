if [ -z "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
    fail-message "Dapr containers not running. Did you run 'dapr init'?"
elif ! grep -qE '^export OPENAI_API_KEY=.+' ~/.bashrc || grep -q 'your_key_here' ~/.bashrc; then
    fail-message "OPENAI_API_KEY is not set (or still the placeholder) in ~/.bashrc. Append your real key with 'echo export OPENAI_API_KEY=...  >> ~/.bashrc'."
else
    echo "Sandbox ready and API key set! 👍"
fi
