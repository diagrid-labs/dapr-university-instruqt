# Dapr Pub/Sub Instruqt 2.0 Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the shared sandbox setup into `modules/dapr-sandbox` (with `dapr-secrets` moved onto it), then ship `dapr-pubsub`, a six-page Instruqt 2.0 lab on the six `ai-agent-tracks-instruqt/pubsub` demos, with drift tests and CI.

**Architecture:** The module gains a `sandbox-setup.sh` that does everything lab-agnostic (Docker/DNS readiness, demo clone, code-server, Dev Dashboard, `dapr init`) and runs before the lab's own `lab_startup_script` in the same strict-mode subshell. The image gains jq, the RabbitMQ image and warm package caches for the pubsub demos. `dapr-pubsub/` copies the `dapr-secrets` lab shape: HCL at the root, one folder per page with `assignment.md`, check scripts, `solve.sh` and a Robot suite.

**Tech Stack:** Instruqt 2.0 HCL + CLI, bash, Python 3.12 + pytest, Robot Framework, GitHub Actions, Dapr 1.19.1, Redis, RabbitMQ 4.4.0.

**Spec:** `docs/superpowers/specs/2026-11-12-dapr-pubsub-instruqt-2-lab-design.md`

## Global Constraints

- Lab title: `Pub/Sub deep dive: Subscription types, CloudEvents, Bulk Publishing and Routing`.
- Time limit `45m`, extend `10m`, idle `10m`, `show_timer = true`, `show_warning = true`. Pages total 42 minutes: 8 / 6 / 7 / 7 / 7 / 7.
- Languages: .NET, Python, Java. No JavaScript.
- `dapr_runtime_version = "1.19.1"` in both labs; it must equal `prewarm_dapr_runtime_version`.
- Demo repo `https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git`, cloned to `/root/ai-agent-tracks-instruqt`. `dapr-pubsub` pins `tracks_src_ref` to the demo repo's `main` SHA at build time (now `37fccac6583f4d5b1854002a234b5d25e4f3f9e8`). Each lab keeps its own pin.
- RabbitMQ image `rabbitmq:4.4.0-management`, container name `rabbitmq`, ports 5672 and 15672.
- Demo ports: `order-api` 5101 / Dapr HTTP 3510; `shipping` or `warehouse` 5102 / 3511; `invoicing` 5103 / 3512. Pub/sub component `pubsub`, topics `orders`, `orders-raw`, `orders-dead`.
- Folder names: .NET `DemoN-PascalCase/PascalApp`, Python and Java `demoN-kebab-case/kebab-app` (see `pubsub/README.md` table).
- No legacy files (`README.md` config, `_setup/`, `tabs.md`, `notes.md`, challenge `README.md`) in `dapr-pubsub/`.
- Each pin lives in one `variable "<name>" { default = "<value>" }` block, read with `tools/track-tester/ci/read_pin.py`.
- No PR that pins an unpublished module version merges. The owner publishes first.
- Never simplify `Stop Process With SIGINT`. Keep fence annotations and `# doc-sync coverage (<why>):` blocks accurate.
- Voice and structure of every page follow `dapr-secrets/3-secret-scoping/assignment.md`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Lab setup re-runs at every VM boot.** `sandbox-setup.sh` run twice must not re-clone over a learner's edits or re-`dapr init` running containers. Test in Task 2.
2. **A learner mixes languages across pages** (Python on page 1, .NET on page 2). Every log-reading check must look in all three language folders, not one. Test in each page task (`test_<page>_check_finds_logs_in_any_language`).
3. **A previous page's apps are still running** on the same fixed ports. A check must then fail with a message that says to press `Ctrl+C` and start this page's demo, not a misleading one. Tested per page with a stub that answers with the wrong app's metadata.
4. **Page 6 out of order:** the learner runs `dapr run -f .` before starting RabbitMQ, or runs the RabbitMQ block twice. The block must be safe to run twice, and the first failing check must say "start RabbitMQ first". Test in Task 11.
5. **Learners who skip a page** (via the page list) arrive at a page whose demo was never built. The background pre-build covers all demos, demo 1 first, and nothing on a page depends on an earlier page having run. Covered by Task 5 and the live run.

---

## File Structure

```
modules/dapr-sandbox/
  main.hcl                       + inputs dapr_runtime_version, demo_repo_url, demo_repo_ref, editor_folder
  versions.hcl                   + jq_version (moved from dapr-secrets)
  scripts/sandbox-setup.sh       NEW: shared boot setup, from dapr-secrets/scripts/lab-setup.sh
  scripts/install-tools.sh       + jq
  scripts/prewarm.sh             + rabbitmq image, + pubsub caches
  README.md
dapr-secrets/
  versions.hcl                   new module version + inputs, jq_version removed
  scripts/lab-setup.sh           secrets-only: secrets.json, Vault, pre-build
dapr-pubsub/
  main.hcl versions.hcl layouts.hcl tabs.hcl pages.hcl tasks.hcl website-description.md
  scripts/lab-setup.sh           background pre-build only
  1-subscription-types/          assignment.md, scripts/check-*.sh, scripts/solve.sh, tests/challenge.robot
  2-streaming-subscriptions/     same
  3-cloudevents/                 same
  4-bulk-messages/               same
  5-routing-and-dead-letters/    same
  6-swap-the-broker/             same
  scripts/lib-checks.sh          shared helpers for the check scripts (log lookup, port probes)
tools/track-tester/
  variables/dapr_pubsub.py
  ci/setup-dapr-pubsub.sh
  ci/tests/test_sandbox_setup.py
  ci/tests/test_pubsub_checks.py
  ci/tests/test_pubsub_pins.py
.github/workflows/test-dapr-pubsub.yml, lab-validate.yml
docs/instruqt-2-spike-checklist.md, docs/instruqt-2-runbook.md, AGENTS.md, README.md,
.claude/skills/creating-dapr-university-tracks/{SKILL.md,reference.md}
```

---

## Part A: shared setup in the module

### Task 1: Spike the three unknowns and record the answers

**Files:**
- Modify: `docs/instruqt-2-spike-checklist.md` (new section "Module shared setup and dapr-pubsub")

**Interfaces:**
- Produces: three recorded answers that Tasks 2, 6 and 11 read:
  - **S1 module script loading:** does `file("scripts/sandbox-setup.sh")` inside `modules/dapr-sandbox/main.hcl` resolve relative to the module, both in `validate-lab.sh` and in a published module? Answer: `file()` or `image`.
  - **S2 log location:** the exact path of each app's log after `dapr run -f .` in each language, e.g. `<demo>/<app>/.dapr/logs/<appid>_app_<timestamp>.log`.
  - **S3 RabbitMQ tab:** with `-p 5672:5672 -p 15672:15672` (all interfaces), does `guest`/`guest` log in through an Instruqt `service` tab on 15672?

- [ ] **Step 1: S2, locally.** Run demo 1 in each language from your local clone (`cd pubsub/<lang>/<demo1> && dapr run -f .`), publish one order with the README curl, stop, then `find pubsub -path '*/.dapr/logs/*'`. Record the path pattern and that the app log contains `shipping received order`.
- [ ] **Step 2: S1, locally.** In a scratch copy of the module, add `variable "probe" { default = file("scripts/install-tools.sh") }` to `main.hcl`, run `tools/track-tester/ci/validate-lab.sh dapr-secrets <scratch-module>`. Record pass or the error.
- [ ] **Step 3: Hand-off to the owner (S1 published, S3).** Write the two owner steps into the checklist: publish a test module version with the probe and check a lab sync; start a test lab with a `service` tab on 15672 and the all-interfaces `docker run`, try `guest`/`guest`. The owner records the answers. If S1 is `file()` in validate but not after publishing, the answer is `image`.
- [ ] **Step 4: Commit** `docs: spike checklist for module shared setup and dapr-pubsub`

### Task 2: Module `sandbox-setup.sh`

**Files:**
- Create: `modules/dapr-sandbox/scripts/sandbox-setup.sh`, `tools/track-tester/ci/tests/test_sandbox_setup.py`
- Modify: `modules/dapr-sandbox/main.hcl`, `modules/dapr-sandbox/README.md`
- Source material: `dapr-secrets/scripts/lab-setup.sh` lines from `HOME` handling through `dapr init`, except `install_jq` and the secrets steps.

**Interfaces:**
- Consumes: S1 from Task 1.
- Produces:
  - `sandbox-setup.sh` requires env `DAPR_RUNTIME_VERSION`, `DEMO_REPO_URL`, `DEMO_REPO_REF`, `EDITOR_FOLDER` (each `: "${X:?X must be set}"`). Defines and leaves defined for the lab script: `log`, `die`, `bounded`, `wait_for_docker`, and exports `HOME`, `TRACKS_SRC_DIR=/root/ai-agent-tracks-instruqt` (as `$HOME/ai-agent-tracks-instruqt`), `LAB_SETUP_LOG`. Steps, in order and behavior-identical to today: HOME, logging, Docker, DNS workaround, HTTPS probe, clone `DEMO_REPO_URL` at `DEMO_REPO_REF` into `TRACKS_SRC_DIR` (only when absent), code-server on 8888 opened on `$TRACKS_SRC_DIR/$EDITOR_FOLDER`, Dev Dashboard on 9090, `dapr init --runtime-version "$DAPR_RUNTIME_VERSION"` unless the three containers run.
  - `main.hcl` new input variables `dapr_runtime_version`, `demo_repo_url` (default the demo repo URL), `demo_repo_ref`, `editor_folder`. `startup_script` becomes: shebang, `set -euo pipefail`, `(`, `export` lines for the four env vars from those inputs, the module script (via `file()` or `source /usr/local/lib/dapr-sandbox/sandbox-setup.sh` per S1), then `variable.lab_startup_script`, `)`, then the marker as today.
  - If S1 = `image`: `render-image-script.sh` writes the script to `/usr/local/lib/dapr-sandbox/sandbox-setup.sh` (mode 0755).

- [ ] **Step 1: Write the failing tests** in `test_sandbox_setup.py`. Run the script with a `PATH` of stub executables (`docker`, `getent`, `curl`, `git`, `code-server`, `diagrid-dapr-dev-dashboard`, `dapr`, `systemctl`, `systemd-run`, `timeout`) that append their argv to a calls file and exit 0, `HOME=tmp_path`, `LAB_SETUP_LOG=tmp_path/log`, `LAB_RESOLV_CONF=tmp_path/resolv.conf`.
  - `test_missing_env_fails_naming_it`: unset `DEMO_REPO_REF` → rc != 0, stderr contains `DEMO_REPO_REF`.
  - `test_runs_dapr_init_with_pinned_runtime`: calls contain `dapr init --runtime-version 1.19.1`.
  - `test_clones_at_ref_and_opens_editor_folder`: calls contain `git ... clone ... <url>` and `checkout --quiet <ref>`; the code-server call ends with `<HOME>/ai-agent-tracks-instruqt/pubsub`.
  - `test_second_run_keeps_clone_and_containers` (Review Focus 1): pre-create `<HOME>/ai-agent-tracks-instruqt/.git` and make the `docker ps` stub print an id → no `clone`, no `dapr init` in calls.
  - `test_helpers_available_to_lab_script`: `bash -c 'source sandbox-setup.sh; declare -F log die bounded'` → rc 0.
  - `test_startup_script_order`: in `main.hcl`, the module script reference comes before `variable.lab_startup_script`, which comes before `touch /var/lib/lab-setup/ready`.
- [ ] **Step 2:** `(cd tools/track-tester && uv run pytest ci/tests/test_sandbox_setup.py -v)` → FAIL (script missing).
- [ ] **Step 3:** Write `sandbox-setup.sh` and change `main.hcl` and `README.md` (inputs table, "what the module's setup does", order module setup → lab script → marker, helpers available to the lab script).
- [ ] **Step 4:** pytest → PASS. `shellcheck --shell=bash modules/dapr-sandbox/scripts/*.sh` → clean. `instruqt lab format modules/dapr-sandbox && git diff --exit-code` → clean. `instruqt lab validate modules/dapr-sandbox` → pass.
- [ ] **Step 5: Commit** `feat(modules): shared sandbox setup in dapr-sandbox`

### Task 3: Image: jq, RabbitMQ, pubsub caches

**Files:**
- Modify: `modules/dapr-sandbox/scripts/install-tools.sh`, `modules/dapr-sandbox/scripts/prewarm.sh`, `modules/dapr-sandbox/scripts/render-image-script.sh`, `modules/dapr-sandbox/versions.hcl`, `tools/track-tester/ci/tests/test_read_pin.py` (or the file holding the render test)

**Interfaces:**
- Produces: `versions.hcl` gets `jq_version = "1.8.1"`; `render-image-script.sh` exports `JQ_VERSION`; `install-tools.sh` installs the jq static binary to `/usr/local/bin/jq` (same URL scheme as today's `install_jq`) and prints `jq --version` in the version block; `prewarm.sh` adds `rabbitmq:4.4.0-management` to `DAPR_IMAGES` (rename the array to `PREWARM_IMAGES`) and warms every pubsub demo app in all three languages after the secrets ones.

- [ ] **Step 1: Failing test** `test_render_image_script_has_jq_rabbitmq_and_pubsub`: output contains `export JQ_VERSION=1.8.1`, `rabbitmq:4.4.0-management`, `pubsub/dotnet/Demo1-Subscriptions`, `pubsub/java/demo4-bulk`, and `bash -n` on it passes. Run → FAIL.
- [ ] **Step 2:** Make the changes. The pubsub warm loop covers every app folder of demos 1 to 5 (`OrderApi`, `Shipping`, `Invoicing`, `Warehouse` / kebab equivalents); demo 6 has no code.
- [ ] **Step 3:** pytest → PASS; shellcheck clean.
- [ ] **Step 4: Real install test:** `render-image-script.sh > $SCRATCH/image.sh`, run it in `ubuntu:24.04` as in the secrets plan Task 3 Step 4. Expected: version block includes `jq-1.8.1`, the pubsub builds succeed.
- [ ] **Step 5: Commit** `feat(modules): jq, RabbitMQ image and pubsub caches in the sandbox image`

### Task 4: Move `dapr-secrets` onto the new module

**Files:**
- Modify: `dapr-secrets/scripts/lab-setup.sh`, `dapr-secrets/versions.hcl`, `tools/track-tester/ci/setup-dapr-secrets.sh`, `AGENTS.md` ("Instruqt 2.0 labs": module owns shared setup)

**Interfaces:**
- Consumes: Task 2 inputs, helpers and `TRACKS_SRC_DIR`.
- Produces: `dapr-secrets/versions.hcl` module block at the new version (the builder picks the number; `1.1.0` unless S1 forced an image-only change that breaks old labs, then `2.0.0`), with `dapr_runtime_version = variable.dapr_runtime_version`, `demo_repo_ref = variable.tracks_src_ref`, `editor_folder = "secrets"`; `lab_environment` keeps only what the secrets script still needs. `jq_version` and `JQ_VERSION` removed. `lab-setup.sh` keeps only: `secrets.json`, `seed_vault`, the background pre-build.

- [ ] **Step 1:** Make the changes. `setup-dapr-secrets.sh` adds `bash -n modules/dapr-sandbox/scripts/sandbox-setup.sh`.
- [ ] **Step 2:** `tools/track-tester/ci/validate-lab.sh dapr-secrets modules/dapr-sandbox` → pass. `python3 tools/track-tester/ci/check_lab_paths.py dapr-secrets` → pass. `(cd tools/track-tester && uv run pytest -v)` → pass. `grep -rn jq_version dapr-secrets` → nothing.
- [ ] **Step 3:** Run the full secrets suites locally: `bash tools/track-tester/ci/setup-dapr-secrets.sh` then `(cd tools/track-tester && uv run robot --outputdir results/secrets ../../dapr-secrets/*/tests/challenge.robot)` → all pass.
- [ ] **Step 4: Commit** `refactor(dapr-secrets): use the module's shared setup`. Open the Part A PR but mark it "do not merge until the module version is published".

### Checkpoint A: owner

Write these steps into `docs/instruqt-2-runbook.md` (section "Module 1.1 / dapr-pubsub") in Task 4, then hand off:

1. Before anything else: start the live `dapr-secrets` lab, run `grep 'done after' /var/log/lab-setup.log`, record the seconds as the baseline in the runbook.
2. Build the image (`render-image-script.sh`), set `image_ref`, publish the new module version.
3. Merge the Part A PR. Start `dapr-secrets` live, compare `done after` with the baseline (must not be slower), click through all four checks.

---

## Part B: the `dapr-pubsub` lab

Part B starts after Task 1 and can run alongside Checkpoint A. Its PR merges only after Checkpoint A.

### Task 5: Lab skeleton, variables and CI setup script

**Files:**
- Create: `dapr-pubsub/{main.hcl,versions.hcl,layouts.hcl,tabs.hcl,pages.hcl,tasks.hcl,website-description.md}`, `dapr-pubsub/scripts/lab-setup.sh`, `dapr-pubsub/scripts/lib-checks.sh`, six `dapr-pubsub/<n>-<slug>/assignment.md` holding only their H1, `tools/track-tester/variables/dapr_pubsub.py`, `tools/track-tester/ci/setup-dapr-pubsub.sh`
- Modify: `.github/workflows/lab-validate.yml` (add `dapr-pubsub` to every loop and a second `validate-lab.sh` call; shellcheck `find` includes `dapr-pubsub`)

**Interfaces:**
- Consumes: module inputs (Task 2).
- Produces:
  - `pages.hcl` resources `subscription_types`, `streaming_subscriptions`, `cloudevents`, `bulk_messages`, `routing_and_dead_letters`, `swap_the_broker`, titled "Subscription types", "Streaming subscriptions", "CloudEvents and raw payloads", "Bulk messages", "Routing and dead letters", "Swap the broker". `tasks.hcl` starts empty; page tasks add their own.
  - `tabs.hcl`: `editor`, `dev_dashboard` as in dapr-secrets; terminals `dapr_cli`, `curl` with `working_directory = "/root/ai-agent-tracks-instruqt/pubsub"`; `service "rabbitmq"` on port 15672 (per S3; drop it and its tab if S3 failed, and page 6 uses the management API through curl instead).
  - `layouts.hcl`: dapr-secrets layout plus a `RabbitMQ` tab in the top panel, inactive.
  - `versions.hcl`: `dapr_runtime_version`, `tracks_src_ref`, module block (`editor_folder = "pubsub"`, `lab_startup_script = file("scripts/lab-setup.sh")`).
  - `lab-setup.sh`: the detached pre-build (log `/var/log/lab-prebuild.log`), demo 1 to 5 apps per language, demo 1 first, `dotnet build` / `uv sync` / `mvn -q -DskipTests package`.
  - `lib-checks.sh` functions: `latest_app_log <demo-key> <app-key>` echoes the newest log path for that app across all three language folders (pattern from S2) or nothing; `port_answers <port>` returns 0 when curl connects. Demo keys `1`..`6`, app keys `order-api shipping invoicing warehouse`.
  - `dapr_pubsub.py`: `TRACKS_SRC_DIR` (as `dapr_secrets.py`), `PUBSUB_BASE`, dicts `DEMO1`..`DEMO6` and `ORDER_API`, `SHIPPING`, `INVOICING`, `WAREHOUSE` keyed by `dotnet`/`python`/`java`, and `RABBITMQ_IMAGE = "rabbitmq:4.4.0-management"`.
  - `setup-dapr-pubsub.sh`: `setup-dapr-secrets.sh` without Vault and without `secrets.json`; reads `tracks_src_ref` and `dapr_runtime_version` from `dapr-pubsub/versions.hcl`; `bash -n` on `dapr-pubsub/scripts/*.sh`.

- [ ] **Step 1:** `tools/track-tester/ci/validate-lab.sh dapr-pubsub modules/dapr-sandbox` → FAIL (no lab).
- [ ] **Step 2:** Write the files.
- [ ] **Step 3:** validate → pass; `check_lab_paths.py dapr-pubsub` → pass; `instruqt lab format dapr-pubsub && git diff --exit-code` → clean; shellcheck clean; `bash tools/track-tester/ci/setup-dapr-pubsub.sh` → completes.
- [ ] **Step 4: Commit** `feat(dapr-pubsub): lab skeleton, pre-build and CI setup`

### Tasks 6 to 11: one task per page

Every page task has the same shape. The table after this block gives what differs.

**Files (per page `<dir>`):**
- Modify: `dapr-pubsub/<dir>/assignment.md`, `dapr-pubsub/tasks.hcl`, `dapr-pubsub/pages.hcl` (`activities`)
- Create: `dapr-pubsub/<dir>/scripts/check-*.sh`, `dapr-pubsub/<dir>/scripts/solve.sh`, `dapr-pubsub/<dir>/tests/challenge.robot`
- Test: `tools/track-tester/ci/tests/test_pubsub_checks.py` (stub HTTP servers on the fixed ports and fake log files under a temp `TRACKS_SRC_DIR`, in the style of `test_secrets_checks.py`)

**Steps (per page):**

- [ ] **Step 1: Failing check tests** for every condition in the table: pass case, fail case, and the gate case (the app's port does not answer → the check exits 0 so only the "is it running" condition reports). Add `test_<page>_check_finds_logs_in_any_language` (fake log only in the java folder → pass) and `test_<page>_wrong_demo_running` (metadata stub answers with another page's app ids → the first condition fails with a message containing `Ctrl+C`). Run → FAIL.
- [ ] **Step 2:** Write the check scripts (source `../../scripts/lib-checks.sh`), `solve.sh` (stop any running demo with `dapr stop -f .` in every language folder, start this page's .NET demo detached with `setsid nohup`, drive the page's requests, wait for the expected log line, as `dapr-secrets/3-secret-scoping/scripts/solve.sh` does), and the `task` in `tasks.hcl` with `timeout = "30s"`, `solve` on the first condition with `timeout = "180s"`, and a `failure_message` per condition that names the fixing action.
- [ ] **Step 3:** pytest → PASS.
- [ ] **Step 4: Write `assignment.md`** following `dapr-secrets/3-secret-scoping/assignment.md`: H1, intro ending "This hands-on lab takes about N minutes to complete.", "Before you start" (pages 2 to 6), numbered steps, first folder-changing Run block `cd /root/ai-agent-tracks-instruqt/pubsub`, `<details>` per language for code to open and the `cd` + `dapr run -f .`, the "wait for the Started Dapr lines" callout, curl commands and expected output outside `<details>`, `<instruqt-task id="...">`, `---`, a one-line result, "What's next?".
- [ ] **Step 5: Write `tests/challenge.robot`**: `Ports Are Free` test, one test per language tagged `dotnet`/`python`/`java` that builds, starts `dapr run -f .`, runs the page's Run-block commands (unique order IDs per run) and asserts the page's expected log lines and responses; then runs the page's check scripts against the running demo and expects rc 0. Trailing `# doc-sync coverage (<why>):` block for commands run through `cwd=`.
- [ ] **Step 6:** `(cd tools/track-tester && uv run python docsync/check_doc_sync.py --require-anchored-cd ../../dapr-pubsub/<dir>/assignment.md ../../dapr-pubsub/<dir>/tests/challenge.robot)` → pass. `uv run robot --outputdir results/<dir> ../../dapr-pubsub/<dir>/tests/challenge.robot` → all three languages pass. validate-lab and `check_lab_paths.py` → pass.
- [ ] **Step 7: Commit** `feat(dapr-pubsub): page <n> <title>`

| Task | Page dir | Min | Demo | Teaches (spec table row) | Task id and conditions (script → asserts) |
|---|---|---|---|---|---|
| 6 | `1-subscription-types` | 8 | DEMO1 | Pub/sub intro and why the broker is behind a component; `subscription-shipping.yaml` vs `invoicing` code; one order to both; metadata types; `scopes` beside `spec`; CloudEvents SDK in `shipping`. Page 1 opens with the Run-button terminal callout. | `subscription_types`: `check-apps-running.sh` → 5101 and 5102 and 5103 answer; `check-declarative.sh` → 3511 metadata has an `orders` subscription of type `DECLARATIVE`; `check-programmatic.sh` → 3512 type `PROGRAMMATIC`; `check-both-received.sh` → shipping and invoicing logs contain `received order` |
| 7 | `2-streaming-subscriptions` | 6 | DEMO2 | No app port, no `Subscription` file; `STREAMING`; `not an order` through the sidecar is logged as unreadable and acknowledged; alpha in Dapr 1.19 | `streaming`: `check-apps-running.sh` → 5101 answers and 3511 answers; `check-streaming.sh` → 3511 type `STREAMING`; `check-received.sh` → warehouse log has `warehouse received order` |
| 8 | `3-cloudevents` | 7 | DEMO3 | Normal vs `/orders/raw`; envelope fields; what raw drops; `rawPayload` is set by the publisher, and on a subscription it does the opposite | `cloudevents`: `check-apps-running.sh`; `check-envelope.sh` → shipping log has `received with envelope` and `parsed CloudEvent`; `check-raw.sh` → shipping log has `received raw:` |
| 9 | `4-bulk-messages` | 7 | DEMO4 | `?count=25&prefix=bulk` → batches 10/10/5; `bulkSubscribe` settings; hand-made bulk body → `SUCCESS` and `DROP` | `bulk_messages`: `check-apps-running.sh`; `check-batches.sh` → shipping log has at least one `received batch of`; `check-per-entry.sh` → the check posts the README's two-entry bulk body to 5102 and expects `"e1","status":"SUCCESS"` and `"e2","status":"DROP"` |
| 10 | `5-routing-and-dead-letters` | 7 | DEMO5 | `routes.rules`, `deadLetterTopic`, resiliency 3 retries 1s constant; standard/express/poison; 4 deliveries then `orders-dead`; why `RETRY` not `DROP` | `routing`: `check-apps-running.sh`; `check-routed.sh` → shipping log has `standard order` and `express order`; `check-dead-lettered.sh` → shipping log has `dead-lettered order` |
| 11 | `6-swap-the-broker` | 7 | DEMO6 | Starts RabbitMQ (Run block below); `dapr.yaml` points at demo 5 apps and two resources folders; same three orders, same output; RabbitMQ tab: exchanges `orders`, `orders-dead`, queues `shipping-orders`, `shipping-orders-dead`. Ends with the dapr-secrets closing (recap one line per page, feedback, three *Next steps* groups, `<instruqt-completion text="You've completed Pub/Sub deep dive!">`), no badge | `swap_broker`: `check-rabbitmq-running.sh` → container `rabbitmq` running, else "Start RabbitMQ with the Run block in step 1 first"; `check-apps-running.sh`; `check-rabbitmq-component.sh` → 3510 metadata: `pubsub` type `pubsub.rabbitmq`; `check-dead-lettered.sh` → `curl -u guest:guest localhost:15672/api/queues` lists `shipping-orders-dead` and the demo 6 shipping log has `dead-lettered order` |

**Page 6 extras (Task 11):**

- The Run block that starts RabbitMQ is the README block with the port flags changed to `-p 5672:5672 -p 15672:15672` and the image `rabbitmq:4.4.0-management`, keeping `docker rm -f rabbitmq` first and the readiness loop with `docker exec -u rabbitmq`. One sentence after it: the ports are open on all interfaces so the RabbitMQ tab can reach the broker, which is fine in a throwaway sandbox; on your own machine keep the README's `127.0.0.1` binding.
- Robot: run the RabbitMQ block twice in a row and expect rc 0 both times (Review Focus 4); suite teardown `docker rm -f rabbitmq`.
- pytest `test_swap_rabbitmq_not_started`: no `rabbitmq` container (docker stub prints nothing) → `check-rabbitmq-running.sh` fails with "Start RabbitMQ".
- `tools/track-tester/ci/tests/test_pubsub_pins.py::test_rabbitmq_tag_matches_prewarm`: the `rabbitmq:` tag in the page 6 assignment's Run block equals the one in `modules/dapr-sandbox/scripts/prewarm.sh`, and equals `RABBITMQ_IMAGE` in `dapr_pubsub.py`.

### Task 12: CI workflow

**Files:**
- Create: `.github/workflows/test-dapr-pubsub.yml`
- Modify: `README.md` (workflow table row)

**Interfaces:**
- Produces: required-check name `dapr-pubsub-result`.

- [ ] **Step 1:** Copy `test-dapr-secrets.yml`. Change: name, `cron: '0 7 * * *'` with the staggering comment, the `changes` path filter (`dapr-pubsub/**`, `modules/dapr-sandbox/**`, `tools/track-tester/**`, the workflow file), `setup-dapr-pubsub.sh`, the suite glob `../../dapr-pubsub/*/tests/challenge.robot`, artifact and report names, the aggregate job `dapr-pubsub-result`. Drop the Vault step. Keep the Maven cache and pre-warm for java, now over the pubsub demos.
- [ ] **Step 2:** `actionlint .github/workflows/test-dapr-pubsub.yml` (or `uvx actionlint`) → clean.
- [ ] **Step 3:** Push the branch, run the workflow with `workflow_dispatch` on it → all four legs and doc-sync green.
- [ ] **Step 4: Commit** `ci(dapr-pubsub): daily drift tests`

### Task 13: Docs and authoring skill

**Files:**
- Modify: `AGENTS.md` (tracks table row for `dapr-pubsub`, "Instruqt 2.0 labs" now two labs, required checks `lab-validate`, `dapr-secrets-result`, `dapr-pubsub-result`, CI table row, directory map with `dapr_pubsub.py` and `setup-dapr-pubsub.sh`), `docs/instruqt-2-runbook.md` (connect the second lab: branch `main`, root directory `dapr-pubsub`; add the required check), `.claude/skills/creating-dapr-university-tracks/SKILL.md` and `reference.md` (a new lab passes `dapr_runtime_version`, `demo_repo_ref`, `editor_folder` to the module and keeps only its own steps in `lab-setup.sh`; `dapr-pubsub` is the 45-minute exception the user approved).

- [ ] **Step 1:** Edit. `grep -rn "only .*dapr-secrets.*2.0\|first \*\*Instruqt 2.0 lab\*\*" AGENTS.md` shows no stale "only lab" claims.
- [ ] **Step 2: Commit** `docs: dapr-pubsub lab, shared module setup, required checks`

### Checkpoint B: owner

1. Merge Part B after Checkpoint A is done.
2. In Instruqt, create the `dapr-pubsub` lab from branch `main`, root directory `dapr-pubsub`.
3. Add `dapr-pubsub-result` to the required checks on `main`.
4. Live run all six pages in one language with a timer: under 45 minutes, no build or image waits, every check passes, `docker run` on page 6 prints no pull progress.
