FOUND=$(find /root/digest-out "$HOME" ai-agent-tracks-instruqt -name pr-digest.md -size +0c 2>/dev/null | head -1)

if [ -n "$FOUND" ]; then
    echo "Digest generated at $FOUND 👍"
else
    fail-message "No non-empty pr-digest.md found. Make sure 'aspire run' is running, you set DIGEST_OUTPUT_DIR=/root/digest-out before starting it, your OpenAI key is valid, and you triggered a digest run with /start."
fi
