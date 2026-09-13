# Workflow state lives in Catalyst, not in this sandbox, so this can only confirm
# you're still authenticated. The real proof is visual: the two /crash/book calls
# in step 5 must return the same confirmation code.
if ! diagrid whoami >/dev/null 2>&1; then
    fail-message "Not logged in to Catalyst. Run 'diagrid login --no-browser' again if your session expired."
else
    echo "Still logged in to Catalyst. If both booking calls returned the same confirmation code, you're done! 👍"
fi
