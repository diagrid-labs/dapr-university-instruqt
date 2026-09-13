Welcome to **Making Spring AI Agents Durable with Dapr Workflow**. In this track you'll run a Spring AI booking agent, crash it on purpose mid-booking, and prove it recovers without booking twice. This first challenge takes about 9 minutes.

## What makes a Spring AI agent durable?

A normal Spring AI agent is a `ChatClient` plus some `@Tool` beans. It works well until the process dies mid-call. Then the conversation, the tool result, and any partial work are all gone.

`diagrid-spring-ai-starter` changes that with no changes to your agent code. Add the dependency, and every `ChatClient.call()` runs as a **Dapr Workflow**: the model turn and each tool call become checkpointed activities. If the process crashes, the workflow resumes from the last completed step instead of starting over.

## Why idempotency matters here

Durability alone is not the whole story. A `ChatClient.call()` is synchronous, so a caller usually reacts to a crash by retrying. If that retry just books again, you get a durable app that still double-books.

This track's agent solves that with a **caller-owned instance id**. You choose an id for a booking and pass it with the call. Repeat that exact call with the same id later, and it **attaches** to the existing run instead of starting a new one. If the run already finished, you get back the same result, not a new booking.

## What you'll build

You'll run a booking agent with one tool, `commitReservation`, that deliberately takes about 30 seconds to "commit" a reservation. That window is where you'll kill the app mid-call. On restart, you'll re-issue the exact same request and watch it return the exact same confirmation code instead of creating a second booking.

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

## 4. Add your OpenAI API key

The agent reads `OPENAI_API_KEY` straight from the shell environment. So it's available in every terminal tab for the rest of this track, append it to `~/.bashrc`:

```bash,run,copy
echo 'export OPENAI_API_KEY="your_key_here"' >> ~/.bashrc
source ~/.bashrc
```

> [!NOTE]
> You'll need a real key from https://platform.openai.com/signup. Replace `your_key_here` with your actual key before running the command above.

---

You have a Catalyst account, the Diagrid CLI installed, and your OpenAI key ready. Let's move on to challenge 2 where you'll read through the booking agent's code.
