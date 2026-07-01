# NOTE: 'aspire run' is a long-lived, blocking process, so it can't be started
# and left running from a single non-interactive solve script. A real OpenAI
# API key (configured in the previous challenge's secrets.json) is also
# required for the agents to work end-to-end. Manual flow:
#
#   1. export DIGEST_OUTPUT_DIR=/root/digest-out
#   2. aspire run   (in the Aspire Terminal; wait for all resources to show Running)
#
# Once 'aspire run' is up, this triggers a digest run and reads the result:
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
