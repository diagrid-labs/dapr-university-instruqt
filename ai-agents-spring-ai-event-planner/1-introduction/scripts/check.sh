if ! command -v diagrid >/dev/null 2>&1; then
    fail-message "Diagrid CLI not found. Run the install command and move it to /usr/local/bin."
elif ! diagrid whoami >/dev/null 2>&1; then
    fail-message "Not logged in to Catalyst. Run 'diagrid login --no-browser' and confirm the code in your browser."
else
    echo "Catalyst account and CLI are set up! 👍"
fi
