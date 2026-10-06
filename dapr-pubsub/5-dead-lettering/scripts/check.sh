# Verify the learner switched the receiver's response to 429 Too Many Requests,
# which is the change that makes Dapr dead-letter the message.
FILE="dapr-pub-sub-deep-dive/Demo7-Resiliency/ReceiverService/Program.cs"

if [ ! -f "$FILE" ]; then
    fail-message "Demo7-Resiliency/ReceiverService/Program.cs not found. Is the dapr-pub-sub-deep-dive repository still cloned?"
elif ! grep -qE '^[[:space:]]*return Results\.Problem\("Too many requests"' "$FILE"; then
    fail-message "The 429 response is still commented out. Remove the '//' in front of the 'Too many requests' line in Demo7-Resiliency/ReceiverService/Program.cs."
elif grep -qE '^[[:space:]]*return Results\.Accepted\(\);' "$FILE"; then
    fail-message "The handler still returns Results.Accepted() first, so it never reaches the 429. Comment that line out with '//'."
else
    echo "The receiver now rejects messages with a 429. 👍"
fi
