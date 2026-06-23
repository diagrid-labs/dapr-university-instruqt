In this challenge you'll re-enable the `before_llm_call` hook so the agent runs **with** the Tavily hook, and watch the same question from challenge 2 get a much better answer that references current information. The goal is to see how silent prompt enrichment gives the agent up-to-date context automatically.

You'll explore why a hook is the right pattern instead of a tool: it fires for every LLM call regardless of model intent, it's decoupled from the UI so the same agent works behind any entry point, and it runs inside the `call_llm` activity, making the Tavily call replay-safe.
