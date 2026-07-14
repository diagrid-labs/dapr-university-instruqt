Same investigation, but now Dapr is saving the agent's work as it goes. The challenge will take about 5 minutes.

Instead of the agent keeping its notes in memory, every step gets saved to a Redis state store. After the run, you can peek into the actual saved state through the terminal — proof it's not just floating in the process anymore.

This is the setup for the crash recovery in the next challenge.

The sandbox for this challenge is being prepared, it should be ready within a few seconds. Once it's ready, click the 'Start' button.

### What you'll learn in this challenge

- How to swap in-memory state for durable state with Dapr
- What a Dapr state store component looks like
- How to check the saved state directly in Redis
- Why this small change makes crash recovery possible