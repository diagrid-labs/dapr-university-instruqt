Let's read through the booking agent before running it. This challenge is Editor-only. No terminal, no running. This challenge takes about 6 minutes.

## 1. Open CrashRecoveryAgentConfig.java

Open `src/main/java/io/diagrid/quickstart/springai/crashrecovery/CrashRecoveryAgentConfig.java` in the **Editor**. Look at lines 29-32:

```java,nocopy
@Bean
ChatClient crashRecoveryAgent(ChatClient.Builder builder) {
  return builder.defaultSystem(SYSTEM).build();
}
```

This is the whole agent definition. There's no durability code here at all. Because `crashRecoveryAgent` is declared as a `ChatClient` **bean**, `diagrid-spring-ai-starter` automatically attaches a durable advisor to it and gives it its own workflow name, `spring-ai.crashRecoveryAgent.workflow`, instead of a generic shared one.

## 2. Open SlowBookingTools.java

Open `src/main/java/io/diagrid/quickstart/springai/crashrecovery/SlowBookingTools.java`. Look at lines 38-52:

```java,nocopy
@Tool(name = "commitReservation",
    description = "Commit a travel reservation with the provider and return a confirmation code")
public String commitReservation(@ToolParam(description = "the booking reference") String reference) {
  LOG.warn(">>> commitReservation({}) — committing over ~{}s. KILL THE APP NOW to test crash"
      + " recovery (POST /crash/kill, or kill -9). It resumes on restart.", reference, delaySeconds);
  try {
    Thread.sleep(delaySeconds * 1000L);
  } catch (InterruptedException e) {
    Thread.currentThread().interrupt();
    throw new IllegalStateException("commitReservation interrupted", e);
  }
  String code = "BK-" + Integer.toHexString(reference.hashCode()).toUpperCase();
  LOG.info(">>> commitReservation({}) — committed. Confirmation code: {}", reference, code);
  return "Booking " + reference + " confirmed. Confirmation code: " + code;
}
```

Two things matter here. First, `commitReservation` sleeps for about 30 seconds. That's the window you'll kill the app in during challenge 4. Second, the confirmation code is derived from the booking `reference`, not randomly generated. So the same reference always produces the same code. That's what lets you prove, later, that a recovered call did not book a second time.

`SlowBookingTools` is annotated `@Component`, which makes it a Spring bean rather than a tool attached per call. The comment above the class explains why that matters: a bean-based `@Tool` is rediscovered every time the app starts, so a workflow that was interrupted mid-tool can find it again after a restart. A tool attached only at call time would be gone.

## 3. Open CrashRecoveryController.java

Open `src/main/java/io/diagrid/quickstart/springai/crashrecovery/CrashRecoveryController.java`. Look at lines 47-64:

```java,nocopy
@GetMapping("/crash/book")
public ResponseEntity<String> book(
    @RequestParam String id, @RequestParam(defaultValue = "ABC123") String reference) {
  try {
    String answer = agent.prompt()
        .user("Confirm the booking with reference " + reference + ".")
        .advisors(a -> a.param(DurableAdvisor.INSTANCE_ID_KEY, id))
        .call()
        .content();
    return ResponseEntity.ok(answer + "\n");
  } catch (DurableCallTimeoutException e) {
    return ResponseEntity.accepted()
        .body("still running as " + e.instanceId()
            + " — re-issue GET /crash/book?id=" + id + " to attach\n");
  }
}
```

The `id` query parameter becomes the workflow's instance id, set through `DurableAdvisor.INSTANCE_ID_KEY`. That id is a bearer handle. Call `/crash/book` again with the same `id`, and instead of starting a fresh booking, the durable runtime attaches to the run already in progress (or already finished) under that id.

Now look at lines 66-71:

```java,nocopy
@PostMapping("/crash/kill")
public void kill() {
  LOG.warn(">>> /crash/kill — halting the JVM to simulate a worker crash");
  Runtime.getRuntime().halt(137);
}
```

`Runtime.getRuntime().halt(137)` stops the JVM immediately, skipping shutdown hooks entirely. It's a controlled way to simulate a hard process kill, like a container getting OOM-killed or a node rebooting mid-request.

## 4. Open application.properties

Open `src/main/resources/application.properties`. Look at lines 10-17:

```text,nocopy
diagrid.spring-ai.enabled=true
diagrid.spring-ai.completion-timeout=2m
```

`diagrid.spring-ai.enabled=true` is what turns on the durability starter. `completion-timeout` is how long the HTTP call blocks waiting for the workflow. It's set well above the tool's 30 second sleep, so the first `/crash/book` call has time to actually reach the crash window instead of timing out first.

## 5. How this works

1. `crashRecoveryAgent` is an ordinary `ChatClient` bean. The starter makes it durable with no code in the bean itself.
2. Every call runs as a Dapr Workflow. The model turn and the `commitReservation` tool call are separate checkpointed activities.
3. The caller supplies the instance id, so a repeated call with the same id attaches to the existing run instead of colliding with it.
4. Because `commitReservation` is a bean, it survives a restart and can complete the resumed workflow.

---

You've read the whole flow without running a single command. Let's move on to challenge 3 where you'll run the agent for real.
