# NOTE: this challenge is interactive — it requires stopping and restarting the
# blocking `aspire run` process around a deliberate crash, which can't be fully
# automated from a single non-interactive script. The manual flow is:
#
#   1. Ctrl+C the running app.
#   2. export DIGEST_OUTPUT_DIR=/root/digest-out && export CRASH_AFTER_AGENT_CALLS=3 && aspire run
#   3. curl -X POST http://localhost:5090/start -d '{"id":"run-crash","repo":"dapr/dapr","maxPrs":7}'
#   4. Wait for the crash, then Ctrl+C.
#   5. unset CRASH_AFTER_AGENT_CALLS && aspire run
#
# Once the app has resumed and is running again, this finishes the run and shows the ledger:
endpoint="http://localhost:5090"
until curl -s "$endpoint/status/run-crash" | grep -qi '"completed"'; do
  sleep 2
done
cat /root/digest-out/agent-calls.log
