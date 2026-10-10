Let's read through the event planner before running it. This challenge is Editor-only. No terminal, no running. This challenge takes about 6 minutes.

## 1. Open EventPlannerAgentConfig.java

Open `src/main/java/io/diagrid/quickstart/springai/eventplanner/EventPlannerAgentConfig.java`. Look at lines 34-37:

```java,nocopy
@Bean("spring-ai-event-planner")
ChatClient eventPlanner(ChatClient.Builder builder) {
  return builder.defaultSystem(SYSTEM).build();
}
```

This is the whole agent definition. There's no durability code here at all. Because `eventPlanner` is declared as a `ChatClient` **bean** with an explicit name, `diagrid-spring-ai-starter` automatically attaches a durable advisor to it, names its workflow `spring-ai.spring-ai-event-planner.workflow`, and registers it as an agent under that same name.

## 2. Open EventPlannerTools.java

Open `src/main/java/io/diagrid/quickstart/springai/eventplanner/EventPlannerTools.java`. Look at lines 38-45:

```java,nocopy
@Tool(name = "step_two_compare",
    description = "Compare the venue options. This is the second step.")
public String stepTwoCompare(@ToolParam(description = "the venues found in step one") String data) {
  LOG.info(">>> TOOL 2: Comparing venues...");
  Runtime.getRuntime().halt(1); // 💥 Comment out this line before the second run — then re-run without re-triggering /run and watch the workflow resume. Use halt(), not System.exit(): halt skips JVM shutdown hooks, so it's an abrupt crash (what we want to simulate) and avoids deadlocking on Spring Boot's graceful shutdown, which would wait on this very request thread.
  LOG.info(">>> TOOL 2 COMPLETE: Grand Ballroom is the best option");
  return "Grand Ballroom is the best option. Now call step_three_confirm.";
}
```

This is where the crash happens, on the very first call, every time, with no manual trigger needed. Notice it uses `Runtime.getRuntime().halt(1)`, not `System.exit()`. `halt()` skips JVM shutdown hooks entirely, so it behaves like a real hard kill instead of a graceful shutdown.

All three tools in this file are annotated `@Component`, making them Spring beans rather than tools attached per call. That matters for the same reason as the deep dive comment explains: a bean-based `@Tool` is rediscovered every time the app starts, so a workflow interrupted mid-tool can find it again after a restart.

Also notice none of the three tools do anything beyond logging and returning a string. That's what makes replaying `step_two_compare` after a crash harmless. There's no booking, no database write, nothing that would behave differently the second time it runs.

## 3. Open EventPlannerController.java

Open `src/main/java/io/diagrid/quickstart/springai/eventplanner/EventPlannerController.java`. Look at lines 28-32:

```java,nocopy
@PostMapping("/run")
public RunResponse run(@RequestBody RunRequest request) {
  String response = chatClient.prompt().user(request.prompt()).call().content();
  return new RunResponse(response);
}
```

One endpoint, one call. There's no instance id here, unlike a track built around a side-effecting tool. Every `POST /run` schedules a brand new workflow, which is fine because nothing this agent does needs to be deduplicated.

## 4. Open application.properties

Open `src/main/resources/application.properties`. Look at lines 15-16:

```text,nocopy
diagrid.spring-ai.enabled=true
diagrid.spring-ai.completion-timeout=5m
```

`diagrid.spring-ai.enabled=true` turns on the durability starter, same as any other Spring AI agent using it.

Now look at lines 24-30:

```text,nocopy
spring.ai.model.chat=${DIAGRID_QUICKSTART_MODEL:none}

spring.ai.openai.api-key=${OPENAI_API_KEY:not-set}
spring.ai.openai.chat.model=gpt-4o-mini
```

By default `DIAGRID_QUICKSTART_MODEL` is unset, which selects an offline canned model instead of a real LLM. That's why this track needs no API key: the model always asks for the same three tools in the same order, so the crash and the recovery are the only moving parts. Setting `DIAGRID_QUICKSTART_MODEL=openai` and a real `OPENAI_API_KEY` would switch to a real model, but you won't need that for this track.

## 5. How this works

1. `eventPlanner` is an ordinary `ChatClient` bean. The starter makes it durable and registers it as an agent with no code in the bean itself.
2. Every call runs as a Dapr Workflow. The model turn and each of the three tool calls are separate checkpointed activities.
3. `step_two_compare` halts the JVM on its first run, every time, simulating a hard crash mid-workflow.
4. Because all three tools are side-effect-free, replaying one after a restart is completely safe.

---

You've read the whole flow without running a single command. Let's move on to challenge 3 where you'll trigger it and watch it crash.
