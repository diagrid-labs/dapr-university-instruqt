# Dapr Pub/Sub as an Instruqt 2.0 lab, plus shared setup in the sandbox module

Status: approved, 2026-11-13.

## Why

Dapr University has no pub/sub deep dive. `dapr-101` touches pub/sub on one page and stops at
"publish, and a subscriber receives it". The demo apps for a deep dive already exist in
`diagrid-labs/ai-agent-tracks-instruqt` under `pubsub/`: six demos, each in .NET, Python and Java,
with smoke tests in `tests/pubsub/`. This project turns them into a lab.

`dapr-secrets` is the model for structure, instructions and verbosity. While building it, about 300
lines of `dapr-secrets/scripts/lab-setup.sh` turned out to have nothing to do with secrets (Docker
and DNS readiness, code-server, the Dev Dashboard, `dapr init`). A second lab would copy them.
Instead they move into the shared `modules/dapr-sandbox` module now, and both labs use it.

## Goals

- A new Instruqt 2.0 lab, `dapr-pubsub/`, with six pages, one per demo, for .NET, Python and Java.
- 45 minutes in total (`timelimit.duration = "45m"`), 10 minutes extra, 10 minutes idle timeout.
  The user approved going past the 30-minute / 5-challenge default.
- On page 6 the learner starts RabbitMQ themselves with a Run block. The `rabbitmq:4.4.0-management`
  image is already pulled into the sandbox image, so the container starts without a download.
- The shared, lab-agnostic setup moves from `dapr-secrets/scripts/lab-setup.sh` into the module.
  `dapr-secrets` moves to the new module version in the same project and keeps passing its suites.
- Drift tests for every page, a CI workflow, and the same guarantees `dapr-secrets` has: doc-sync
  with `--require-anchored-cd`, a `changes` path filter, and an aggregate required check.

## Non-goals

- No changes to the demo apps in `ai-agent-tracks-instruqt`, unless a page cannot be written
  without one. If that happens, the fix goes upstream first and the lab pins the new commit.
- No JavaScript. The demos exist in .NET, Python and Java only.
- No Kubernetes, no Catalyst, no other brokers than Redis and RabbitMQ.
- No legacy 1.0 files (`README.md` config, `_setup/`, `tabs.md`, `notes.md`, challenge
  `README.md`) in `dapr-pubsub/`. It starts as a clean 2.0 lab.
- Removing the legacy files that are still in `dapr-secrets/` is out of scope.

## Anti-goals (a failure even if it technically works)

- Pages that read like the upstream `pubsub/README.md` pasted in. That README is reference
  material for running the demos locally. The pages follow the `dapr-secrets` voice: short
  sentences, one idea per step, the *why* after each observation.
- A learner who waits on a cold build or an image download in the middle of a page.
- RabbitMQ that is already running when the learner reaches page 6. The point of the page is that
  the learner starts the broker and then sees Dapr move onto it.
- A module refactor that breaks `dapr-secrets` or makes it slower to start.
- Shared setup copied into a second lab script "for now".

## Current state

- `modules/dapr-sandbox` (module `1.0.2`, image `diagrid/dapr-sandbox-2:v1`) gives one VM with the
  toolchain. Its `startup_script` runs the lab's `lab_startup_script` in a subshell and then writes
  `/var/lib/lab-setup/ready`. `prewarm.sh` pre-pulls the Dapr, Redis, Zipkin and Vault images and
  warms the NuGet, Maven and uv caches for the secrets demos only.
- `dapr-secrets/scripts/lab-setup.sh` does, in order: `HOME` and logging helpers, wait for Docker,
  the DNS workaround (public resolvers, Docker daemon DNS, Docker restart), an outbound HTTPS probe,
  install jq, clone `ai-agent-tracks-instruqt` at `TRACKS_SRC_REF`, start code-server on 8888 on the
  `secrets` folder, start the Dev Dashboard on 9090, `dapr init`, then the secrets-only steps
  (generate `secrets.json`, seed Vault, background pre-build).
- `ai-agent-tracks-instruqt/pubsub` at `37fccac`: the six demos. Same app IDs and ports in every
  language: `order-api` 5101 / Dapr HTTP 3510, `shipping` or `warehouse` 5102 / 3511, `invoicing`
  5103 / 3512. Folders are PascalCase in .NET (`Demo1-Subscriptions/OrderApi`) and kebab-case in
  Python and Java (`demo1-subscriptions/order-api`). The Redis `pubsub` component is in
  `<lang>/resources/pubsub.yaml`; each demo adds its own `resources/`.

## Target design

### Part A: shared setup in the module

**What moves into the module** (from `dapr-secrets/scripts/lab-setup.sh`, behavior unchanged):

- `HOME=/root` for root, `log`, `die` and `bounded` helpers, `/var/log/lab-setup.log`.
- Wait for Docker, the DNS workaround, the outbound HTTPS probe.
- Clone a demo repo at a pinned ref, with the retry loop and the "not at pinned ref" warning.
- Start code-server on 8888 (with the same VS Code settings) on a lab-chosen folder.
- Start the Dev Dashboard on 9090.
- `dapr init --runtime-version <version>`, skipped when the containers already run.

**What stays in the lab:** everything about the lab's own topic. For `dapr-secrets`: generating
`secrets.json`, seeding Vault, the background pre-build. For `dapr-pubsub`: the background
pre-build only.

**jq goes into the image** (`install-tools.sh`, pinned in the module's `versions.hcl`), and the
`jq_version` pin and `install_jq` leave `dapr-secrets`. The comment in `dapr-secrets/versions.hcl`
already asks for this. (My call.)

**New module inputs** (names are the builder's call, the set is not): the Dapr runtime version, the
demo repo URL and ref, and the Editor folder. The module runs its own setup first and then the
lab's `lab_startup_script` in the same strict-mode subshell, so a lab script can use `log`, `die`,
`bounded` and the cloned repo. The ready marker stays owned by the module, written last.

**Image changes** (`prewarm.sh`): pull `rabbitmq:4.4.0-management`, and warm the package caches for
all pubsub demos in all three languages (the Java demos use Spring Boot 4.0.8, so their Maven
dependencies differ from the secrets demos). Add jq to `install-tools.sh`. Rebuild the image,
publish a new module version, and pin it in both labs. This is an interface change, so it is a new
minor or major module version, the builder decides which.

**`prewarm_dapr_runtime_version`** must still equal each lab's `dapr_runtime_version`. Both labs
use `1.19.1`.

**Order of delivery:** Part A ships first, with `dapr-secrets` moved onto it and its full
`test-dapr-secrets.yml` green, plus one live `dapr-secrets` start in Instruqt. Then Part B.

**Who does what, and what waits** (my call):

- The repo owner does every step that happens in the Instruqt UI or in GitHub settings: build
  and publish the image, publish the module version, connect the `dapr-pubsub` lab to `main` with
  root directory `dapr-pubsub`, change the required checks, and do the live runs. The plan marks
  each of these as a hand-off with exact instructions, as `docs/instruqt-2-runbook.md` does.
- Part B work starts in parallel with Part A against the local module copy (`validate-lab.sh`, the
  Robot suites, CI). Merge order is fixed: no PR that pins the new module version merges before
  the owner confirms it is published. A pin to an unpublished version breaks the lab on the next
  push (see the comment in `dapr-secrets/versions.hcl`).
- Before Part A changes anything, record the current `dapr-secrets` start time as the baseline
  for "no slower than today": the `done after Ns` line in `/var/log/lab-setup.log` from a live
  start.
- Each lab keeps its own `tracks_src_ref`, so the two labs may pin different commits of the demo
  repo.

### Part B: the `dapr-pubsub` lab

**Layout** (copied from `dapr-secrets`, no legacy files):

```
dapr-pubsub/
  main.hcl  versions.hcl  layouts.hcl  tabs.hcl  pages.hcl  tasks.hcl
  website-description.md
  scripts/lab-setup.sh               pubsub-only steps (background pre-build)
  1-subscription-types/              assignment.md, scripts/check-*.sh, solve.sh, tests/challenge.robot
  2-streaming-subscriptions/
  3-cloudevents/
  4-bulk-messages/
  5-routing-and-dead-letters/
  6-swap-the-broker/
```

**`main.hcl`:** title "Pub/Sub deep dive: Subscription types, CloudEvents, Bulk Publishing and
Routing" (decided by the user). Description in the `dapr-secrets` form: a "you'll learn"
list of six bullets, "around 42 minutes to complete the 6 labs", the 45 + 10 minutes and the idle
line. One chapter, six pages.

**`versions.hcl`:** `dapr_runtime_version = "1.19.1"`, `tracks_src_ref` = the
`ai-agent-tracks-instruqt` commit that is current when the lab is built (now `37fccac`), the
module block at the new version. A `rabbitmq_image` pin is not needed in this file: the image tag
appears in the page 6 Run block and in `prewarm.sh`. The builder adds a check (pytest in
`lab-validate`, or the page 6 suite) that the two tags match, so the pre-pull cannot silently stop
helping.

**Tabs and layout:** the same as `dapr-secrets` (Editor and Dev Dashboard on top, Dapr CLI and curl
terminals side by side below), plus a **RabbitMQ** tab (a `service` on port 15672) next to the
Editor and Dev Dashboard. The terminals' `working_directory` and the Editor folder are
`/root/ai-agent-tracks-instruqt/pubsub`.

**Each page** follows `dapr-secrets`:

- H1 title, an intro that ends "This hands-on lab takes about N minutes to complete."
- From page 2 on, a "Before you start" section: check the Dev Dashboard, stop running apps with
  `Ctrl+C`.
- Numbered `## N.` steps. The first Run block that changes folder is
  `cd /root/ai-agent-tracks-instruqt/pubsub` (doc-sync runs with `--require-anchored-cd`).
- Per-language `<details>` blocks (`.NET`, `Python`, `Java`) for opening code and the `cd` into the
  demo folder. Everything that is the same in every language (curl commands, expected output,
  YAML) stays outside the `<details>` blocks.
- Expected output in `text,nocopy` or `json,nocopy`, curl through `jq` where it helps.
- A check task at the end, run while the apps are still running, then "stop with `Ctrl+C`".
- `---`, one line on what the learner can do now, and a "What's next?" paragraph.

**Page content** (the facts come from the upstream README and the demo code; the builder writes the
prose):

| # | Page | Minutes | What the learner does and sees | Task checks (sketch) |
|---|---|---|---|---|
| 1 | Subscription types | 8 | What pub/sub is and why the broker sits behind a component. Opens `subscription-shipping.yaml` and the `invoicing` code. Publishes one order: both `shipping` and `invoicing` receive it. Metadata endpoints on 3511 and 3512 show `DECLARATIVE` and `PROGRAMMATIC`. Notes that `scopes` sits beside `spec`, and that `shipping` reads the CloudEvent with the CloudEvents SDK, not a Dapr SDK. | both sidecars list their subscription with the right type; both apps logged the order |
| 2 | Streaming subscriptions | 6 | `warehouse` has no app port and no `Subscription` file. Publishes an order, metadata on 3511 shows `STREAMING`. Publishes `not an order` through the sidecar and sees it logged as unreadable and still acknowledged. Mentions that streaming is alpha in Dapr 1.19. | `warehouse` subscription is `STREAMING`; it logged the order |
| 3 | CloudEvents and raw payloads | 7 | Publishes normally and through `/orders/raw`. Compares the envelope with the bare order. Learns that `rawPayload` is set by the publisher, and what the same flag on a subscription would do instead. | `shipping` logged an envelope and a raw order |
| 4 | Bulk messages | 7 | One call publishes 25 orders, which arrive in batches of 10, 10 and 5. Posts a hand-made bulk body and sees `SUCCESS` and `DROP` per entry. | the batch log lines are there; the per-entry statuses come back |
| 5 | Routing and dead letters | 7 | Opens the `routes.rules` and `deadLetterTopic` in the subscription and the resiliency policy. Sends standard, express and poison orders. Sees the routing, four deliveries of the poison order, then `orders-dead`. | routed log lines for both priorities; the poison order is dead-lettered |
| 6 | Swap the broker | 7 | Starts RabbitMQ with a Run block (the README's `docker run`, with the readiness loop). Opens `demo6-swap-provider/dapr.yaml`: the same Demo 5 apps, a `pubsub` component of type `pubsub.rabbitmq`. Runs it, sends the same three orders, gets the same output. Opens the RabbitMQ tab and finds the `orders` and `orders-dead` exchanges and the `shipping-orders` queues Dapr created. Closes the lab. | RabbitMQ is up; the loaded `pubsub` component is `pubsub.rabbitmq`; the poison order is dead-lettered on RabbitMQ |

Total: 42 minutes.

The check scripts may read the apps' logs from the `.dapr/logs` folders that `dapr run -f`
writes, or ask the sidecars' metadata endpoints. The builder picks per condition. Every condition
has a `failure_message` that names the action that fixes it, as in `dapr-secrets/tasks.hcl`. The
first condition of each task has a `solve`.

**Page 6 closing:** the `dapr-secrets` closing, adapted: a recap with one line per page, "Feedback
and further learning", the three *Next steps* groups, and `<instruqt-completion>`. No Holopin badge.

**Pre-build (`scripts/lab-setup.sh`):** a detached background job, as in `dapr-secrets`, that
builds every demo app in all three languages, demo 1 first. Demo 6 has no app code. Logs go to
`/var/log/lab-prebuild.log`.

### Part C: tests and CI

- `tools/track-tester/variables/dapr_pubsub.py`: `TRACKS_SRC_DIR` (same env var and fallback as
  `dapr_secrets.py`) and `PUBSUB_BASE`, plus the demo folder names per language.
- `tools/track-tester/ci/setup-dapr-pubsub.sh`: the same as `setup-dapr-secrets.sh`, without Vault.
  RabbitMQ is not started here: the page 6 suite runs the assignment's own Run block.
- One `tests/challenge.robot` per page, a test case per language tagged `dotnet`, `python`, `java`,
  plus untagged shared tests where a step does not depend on the language. Order IDs unique per run.
  Page 6 removes the `rabbitmq` container in its suite teardown.
- `.github/workflows/test-dapr-pubsub.yml`: the `test-dapr-secrets.yml` structure (changes filter,
  doc-sync job, matrix `dotnet`, `java`, `python`, `shared`, `failed-<leg>.txt`, `drift-report`
  issue, aggregate `dapr-pubsub-result`). Daily at 07:00 UTC.
- `lab-validate.yml` also validates `dapr-pubsub` (format, referenced files, `validate-lab.sh`).
- Required checks on `main` become `lab-validate`, `dapr-secrets-result` and `dapr-pubsub-result`.

### Docs to update

- `AGENTS.md`: the track table, "Instruqt 2.0 labs" (module now owns the shared setup, two labs),
  the required checks, the CI workflow table, the directory map.
- `modules/dapr-sandbox/README.md`: the new inputs, what the module's setup does, the order of
  module setup and lab script.
- `docs/instruqt-2-runbook.md`: the owner steps for a second lab (connect `main`, root directory
  `dapr-pubsub`) and for publishing the new module version before the pins change.
- The `creating-dapr-university-tracks` skill: a new lab no longer copies the shared parts of
  `lab-setup.sh`.

## Success criteria

- `dapr-secrets` on the new module: all suites green in CI, a live start in Instruqt, the lab
  ready no slower than today.
- `dapr-pubsub`: all six suites green in all three languages, doc-sync green, `lab-validate` green.
- A live run through all six pages in one language finishes within 45 minutes with no waits on
  builds or image pulls, and every check task passes after following the page.
- On page 6, `docker run` of RabbitMQ does not pull the image.

## Risks to spike first

- **The RabbitMQ tab.** The upstream command binds 15672 to `127.0.0.1`. Instruqt's service proxy
  needs a port it can reach (the Dev Dashboard binds `0.0.0.0` for this). **Decided (user):** the
  lab's page 6 Run block differs from the upstream README and publishes 15672 (and only what the
  tab needs) on all interfaces. Page 6 says in one line why that is fine in a throwaway sandbox,
  and that the README's localhost-only binding is the right choice on your own machine. The demo
  repo does not change. Spike first: whether the `guest` login works through the tab (the official
  image is believed to set `loopback_users.guest = false`, confirm it). If it does not, create a
  user with `RABBITMQ_DEFAULT_USER`/`RABBITMQ_DEFAULT_PASS` only if the `pubsub.rabbitmq`
  component's `guest` connection still works, otherwise ask the user. The image-tag match check
  compares the page 6 Run block with `prewarm.sh`.
- **Module setup from files.** The module now inlines a script string. Check that a module can
  `file()` its own scripts (relative to the module) when published, or render them into the
  string another way.
- **Log files for checks.** Confirm that `dapr run -f` writes the app logs where the check scripts
  expect them in all three languages.

## Left to the builder

- Module input names, version number, and how the module script is structured.
- Page slugs and titles (the table above is the intent), and the exact prose.
- Which check conditions read logs and which ask the sidecars.
- Whether the Java legs need more than the `dapr-secrets` timeouts.
