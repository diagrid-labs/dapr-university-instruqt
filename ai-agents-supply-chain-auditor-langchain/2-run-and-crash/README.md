# Name

Run and Crash the LangGraph agent

## Url

supply-chain-auditor-langgraph-run-and-crash

### Description

Run the auditor against a real Dependabot PR as a durable Dapr Workflow. Watch the gather_evidence and analyze (Claude) nodes run, then crash the process on purpose inside render_report and inspect the checkpointed state that survived in Redis.
