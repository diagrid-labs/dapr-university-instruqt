In this challenge you'll run the expert agent **without** the Tavily hook, so the `DurableAgent` talks to the LLM directly and answers purely from its training data. The goal is to establish the **baseline** behavior before the hook is introduced in challenge 3.

You'll ask a "current events" question that the model can't know from its training cutoff and see it either hedge or give a confident-but-stale answer. This sets up the problem solved in challenge 3 — giving the model fresh context automatically.
