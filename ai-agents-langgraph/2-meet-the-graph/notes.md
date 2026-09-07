The sandbox for this challenge is being prepared, it should be ready within a few seconds. Once it's ready, click the *Start* button.

---

This challenge takes you through the application code. You'll open `main.py`, `tools.py` and `fake_model.py` and see exactly how LangGraph builds the Schedule Planner's tool-calling loop, and how a single line turns it into a Dapr Workflow. This challenge takes about 6 minutes.

### What you'll learn in this challenge

- How LangGraph builds an agent from nodes, edges, and state
- How a Python function becomes a tool the model can call
- How `build_model()` picks between the canned offline model and a real provider
- How `bind_tools` tells the model which tools it can call
- What a conditional edge is and how the tool-calling loop works
- What `DaprWorkflowGraphRunner` adds on top of the graph
- How the agent becomes an HTTP service

If you have any questions or feedback about this track, you can let us know in the *#general* channel of the [Dapr Discord server](https://diagrid.ws/dapr-discord).
