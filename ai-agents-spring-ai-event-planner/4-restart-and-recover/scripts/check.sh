# Workflow state lives in Catalyst, not in this sandbox, so this can only confirm
# you're still authenticated. The real proof is visual: TOOL 1 must not print again
# in the Terminal after the restart.
if ! diagrid whoami >/dev/null 2>&1; then
    fail-message "Not logged in to Catalyst. Run 'diagrid login --no-browser' again if your session expired."
else
    echo "Still logged in to Catalyst. If TOOL 2 and TOOL 3 completed after the restart without TOOL 1 printing again, you're done! 👍"
fi
