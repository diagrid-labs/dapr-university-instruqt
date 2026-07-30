# Name

Resume and Recover the LangGraph agent

## Url

supply-chain-auditor-langgraph-resume

### Description

Comment out the crash and re-run the same command. Dapr reconnects to the in-flight workflow and replays gather_evidence and analyze from durable state, with no re-fetch and no second Claude call, proving the expensive step ran exactly once.
