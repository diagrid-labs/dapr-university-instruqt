# Assumes 'aspire run' is already running with a valid OpenAI key (challenge 2).
endpoint="http://localhost:5090"

curl -s -X POST "$endpoint/start" -H "Content-Type: application/json" -d '{
  "id": "run-1",
  "repo": "dapr/dapr",
  "maxPrs": 7
}'

until curl -s "$endpoint/status/run-1" | grep -qi '"completed"'; do
  sleep 2
done

cat /root/digest-out/pr-digest.md
