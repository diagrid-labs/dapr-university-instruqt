if ! command -v diagrid >/dev/null 2>&1; then
    fail-message "Diagrid CLI not found. Run the install command and move it to /usr/local/bin."
elif ! diagrid whoami >/dev/null 2>&1; then
    fail-message "Not logged in to Catalyst. Run 'diagrid login --no-browser' and confirm the code in your browser."
elif ! grep -qE '^export OPENAI_API_KEY=.+' ~/.bashrc || grep -q 'your_key_here' ~/.bashrc; then
    fail-message "OPENAI_API_KEY is not set (or still the placeholder) in ~/.bashrc. Append your real key with 'echo export OPENAI_API_KEY=...  >> ~/.bashrc'."
else
    echo "Catalyst account, CLI, and API key are all set! 👍"
fi
