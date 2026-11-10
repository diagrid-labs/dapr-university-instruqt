Welcome to **Making Spring AI Agents Durable with Dapr Workflow**. In this track you'll run a Spring AI agent that plans an event in three steps, crash it on purpose partway through, and prove it finishes the plan without redoing any completed step. This first challenge takes about 8 minutes.

## What makes a Spring AI agent durable?

A normal Spring AI agent is a `ChatClient` plus some `@Tool` beans. It works well until the process dies mid-call. Then the conversation, the tool results, and any partial work are all gone.

`diagrid-spring-ai-starter` changes that with no changes to your agent code. Add the dependency, and every `ChatClient.call()` runs as a **Dapr Workflow**: the model turn and each tool call become checkpointed activities. If the process crashes, the workflow resumes from the last completed step instead of starting over.

## Why idempotent tools matter

A durable activity is *at-least-once*. If the process crashes while a tool is running, that tool call runs again on recovery. That's fine as long as running it twice has no different effect than running it once.

The agent you'll run in this track has three tools that only log and return a string. None of them touch a database, send an email, or book anything real. That's deliberate. It's what makes a crash mid-tool safe to just replay. A tool with a real side effect, like a booking or a payment, needs its own idempotency strategy, which is a different track's problem.

## What you'll build

You'll run an **Event Planner** agent with three tools called in sequence: search for a venue, compare options, and confirm a booking. The second tool crashes the process the first time it runs. You'll restart the app and watch it finish the plan from where it left off, without re-triggering the original request.

## 1. Create a Diagrid Catalyst account

This track runs on **Diagrid Catalyst**, which is what durably hosts the workflow behind your agent. Sign up for a free account using the **Catalyst** tab on the left in this sandbox, with your email address or a Google or GitHub account.

> [!NOTE]
> Alternatively you can use another browser tab and visit [https://catalyst.diagrid.io/signup](https://catalyst.diagrid.io/signup) to sign up.

> [!IMPORTANT]
> If a tab or terminal isn't available, or you hit any blocking issue during this course, send me [an email](mailto:marc@diagrid.io) and we'll figure it out together.

If you already have an account, you can skip signup and go straight to installing the CLI below.

## 2. Download and install the Diagrid CLI

Use the **Terminal** window:

```bash,run
curl -o- https://downloads.diagrid.io/cli/install.sh | bash
```

Move it onto your path:

```bash,run
sudo mv ./diagrid /usr/local/bin
```

Check it's installed:

```bash,run
diagrid -h
```

## 3. Log in to Catalyst

```bash,run
diagrid login --no-browser
```

> [!NOTE]
> On your own machine, plain `diagrid login` opens a browser tab automatically. `--no-browser` is only needed here because this sandbox can't open one for you.

You'll see something like:

```text,nocopy
logging in to 'https://api.r1.diagrid.io/'...
Visit: https://login.diagrid.io/activate?user_code=XXXX-XXXX and confirm the code matches: XXXX-XXXX
Code confirmed? (Y/N)
```

Open the login link in a new browser tab, confirm the code matches, click *Confirm*, then come back here and press `Y` followed by `Enter` in the **Terminal**.

Once logged in, verify with:

```bash,run
diagrid whoami
```

> [!NOTE]
> No OpenAI key needed for this track. The agent ships with an offline model that always gives the same responses, so the crash and the recovery are the only moving parts.

> [!IMPORTANT]
> Click the *Check* button to verify your Catalyst login before continuing.

---

You have a Catalyst account and the Diagrid CLI installed. Let's move on to challenge 2 where you'll read through the event planner's code.
