if ! command -v aspire >/dev/null 2>&1; then
    fail-message "The Aspire CLI isn't available yet. The sandbox may still be initializing — wait a moment and click Check again."
elif [ ! -d "ai-agent-tracks-instruqt/MAF/PrDigest" ]; then
    fail-message "The PrDigest source wasn't found. Did the sandbox finish setting up? Expected 'ai-agent-tracks-instruqt/MAF/PrDigest'."
elif [ -z "$(docker ps -f "name=dapr_placement" -f "status=running" -q)" ]; then
    fail-message "Dapr doesn't appear to be initialized. Run 'dapr init' and try again."
else
    echo "Environment ready! 👍"
fi
