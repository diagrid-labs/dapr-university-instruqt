LEDGER=$(find /root/digest-out "$HOME" ai-agent-tracks-instruqt -name agent-calls.log 2>/dev/null | head -1)

if [ -z "$LEDGER" ] || [ ! -s "$LEDGER" ]; then
    fail-message "No agent-call ledger (agent-calls.log) found. Run the crash-and-resume steps first."
else
    total=$(grep -c . "$LEDGER")
    unique=$(cut -f2 "$LEDGER" | sort -u | grep -c .)
    if [ "$total" -eq 7 ] && [ "$unique" -eq 7 ]; then
        echo "Durability proven: 7 agent calls, no duplicates! 👍"
    else
        fail-message "Expected 7 unique agent calls; found total=$total unique=$unique. Make sure the resumed 'run-crash' workflow reached 'Completed'."
    fi
fi
