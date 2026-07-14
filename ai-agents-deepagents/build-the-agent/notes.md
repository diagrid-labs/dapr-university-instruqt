Time to run your first investigation. You'll point a DeepAgent at issue in `dapr/dapr` repository. Its a real closed bug with plenty of threads to pull on. The challenge will take about 5 minutes.

The agent reads from a local copy of the issue and its comments, so nothing hits GitHub live. It'll plan its own approach, call its tools, and write up what it finds in a file.

It works. But it's all happening in memory. If anything crashes, it's gone. That's what we fix next.

The sandbox for this challenge is being prepared, it should be ready within a few seconds. Once it's ready, click the 'Start' button.

### What you'll learn in this challenge

- How to run a DeepAgent from the command line
- What it looks like when an agent plans and calls tools on its own
- Where the finished investigation report ends up
- Why running it all in memory is a problem