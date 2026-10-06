# Apply the code change the assignment asks for: comment out the 202 Accepted
# response and activate the 429 Too Many Requests response.
FILE="dapr-pub-sub-deep-dive/Demo7-Resiliency/ReceiverService/Program.cs"

sed -i 's|^\([[:space:]]*\)return Results\.Accepted();|\1//return Results.Accepted();|' "$FILE"
sed -i 's|^\([[:space:]]*\)//return Results\.Problem("Too many requests"|\1return Results.Problem("Too many requests"|' "$FILE"
