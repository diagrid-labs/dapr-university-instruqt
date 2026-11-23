A process that runs for minutes or days will be interrupted at some point: a crash, a deploy, a restart. Dapr Workflow lets you write that process as ordinary code that picks up where it left off.

In this 45-minute lab you'll use Dapr Workflow from .NET, Python, Java, or TypeScript. You'll start a warp jump on the *ISV Meridian*, stop the app halfway, and watch the workflow continue from the last completed step when it comes back. Then you'll run the common patterns: task chaining, fan-out/fan-in, and a monitor that checks a value until it is stable.

Next you'll build a workflow that waits for the captain's authorization, an external event with a timeout. Finally, you'll pause, resume, terminate and purge a running workflow, from your own app and with the Dapr CLI.

You'll finish knowing what makes a workflow durable, which pattern fits which problem, and how to manage workflows once they run.
