# Migrate dapr-101 to an Instruqt 2.0 lab

## Intent

`dapr-101` is the entry track of Dapr University and the last high-traffic track still on the
legacy Instruqt 1.0 format. Move it to the 2.0 lab format used by `dapr-pubsub` and `dapr-secrets`.
That means the shared `diagrid/dapr-sandbox` module, HCL config, the Editor and Dev Dashboard tabs,
and the same page style and CI shape. Learners then get the same sandbox and the same look across
the 101 track and the deeper tracks it leads into.

This is a migration, not a rewrite. The track teaches the same thing in the same five pages. Only
four things change on purpose:

1. **The Dapr CLI is already installed and `dapr init` has already run** when the sandbox starts
   (the module does both). Page 2 no longer asks the learner to run the install script or
   `dapr init`. It still has them verify the result: `dapr -h`, `dapr --version` and the four Dapr
   containers.
2. **The page style becomes 2.0**, as described in the `creating-dapr-university-tracks` skill:
   - H1s;
   - the "This hands-on lab takes about N minutes" intro;
   - the run-section callouts;
   - an anchored `cd`;
   - `## Before you start` and "Stop the applications" sections;
   - Editor and Dev Dashboard instead of language tabs and a Redis terminal;
   - "What's next?" closes;
   - the final-page closing.
3. **The Dev Dashboard does the inspection.** The image has Diagrid's Dapr Dev Dashboard, and the
   pages use it to check app health, inspect state records, inspect the pub/sub subscription and
   publish a message, and read app and sidecar logs. See "Dev Dashboard" below.
4. **The last page recommends `dapr-pubsub`** under "Try another university track", in place of
   `catalyst-101`.

## Goals

- `dapr-101/` is a 2.0 lab that passes `lab-validate`, with a drift suite per page. CI is shaped
  like `test-dapr-pubsub.yml` and has a required aggregate check.
- The same five pages, the same four languages (.NET, Python, Java, JavaScript) and the same
  concepts and examples.
- Demo apps live in `diagrid-labs/ai-agent-tracks-instruqt` under `dapr-101/`, pinned by commit,
  like the other 2.0 labs.
- No 1.0 files left in `dapr-101/`.

## Non-goals

- New content, new pages, new APIs, or rewriting the examples. The apps are copied, not
  redesigned.
- Changing the sandbox module or image. Everything dapr-101 needs is in the image already:
  .NET 10 SDK, Java 17 with Maven, Python with uv, Node 24, the Dapr CLI, and an initialized Dapr
  with Redis, Zipkin, placement and scheduler.
- Migrating any other legacy track.
- Switching the live Instruqt track over. The owner does that (see Hand-off).

## Anti-goals

- A page that asks the learner to install the CLI or run `dapr init`. Running `dapr init` again in
  the sandbox would re-init a working setup, so it must not appear as a Run block or as a command to
  copy.
- Dropping the checks that page 2 used to do. The learner still sees proof that the CLI, the
  runtime and the containers are there.
- Demo code that still depends on `dapr/quickstarts` at run time or in CI.

## Decisions (made with the user)

- **Demo source:** copy the apps into `ai-agent-tracks-instruqt/dapr-101/`. Don't clone
  `dapr/quickstarts`. The module always clones its demo repo to `/root/ai-agent-tracks-instruqt`,
  and the other labs work this way.
- **Scope:** keep the five pages and all four languages, including JavaScript. Keep the content
  as it is, apart from the three changes above.
- **Next track:** "Try another university track" on page 5 lists Dapr Workflow (unchanged) and
  Dapr Pub/Sub (`https://www.diagrid.io/university/pubsub`, the link the other labs already use).
  It drops `catalyst-101`.

## Lab shape

Root files are copied from `dapr-secrets` and adapted:

- `main.hcl`:
  - title: keep "Dapr 101 - State Management, Service Invocation, and Pub/Sub APIs";
  - the four learn bullets from today's `README.md`;
  - the minutes line, the sandbox line, the timeout line and the badge lines in the 2.0 wording;
  - one chapter `dapr101` with five `page` entries.
- `pages.hcl`: one resource per page, with the titles below.
- `layouts.hcl` and `tabs.hcl`: copied from `dapr-secrets`. Both terminals use
  `working_directory = "/root/ai-agent-tracks-instruqt/dapr-101"`. No extra layout and no extra
  service.
- `versions.hcl`:
  - `dapr_runtime_version`: the same value as `dapr-pubsub` and `prewarm_dapr_runtime_version`;
  - `tracks_src_ref`: the commit that adds `dapr-101/` to the demo repo;
  - `module "sandbox"` with the same published module version as `dapr-pubsub` and
    `editor_folder = "dapr-101"`.
- `scripts/lab-setup.sh`: checks that `$TRACKS_SRC_DIR/dapr-101` exists, then pre-builds the
  page 4 and page 5 apps in a detached background job, the same pattern as `dapr-pubsub`:
  - `dotnet build`;
  - `uv sync --all-packages`;
  - `mvn -q -DskipTests install`;
  - `npm install`.
- `website-description.md`: prose for the Dapr University site, written in the style of the
  other two labs.

### Pages

| # | Folder | Title (H1 = `pages.hcl`) | Min | What changes |
|---|---|---|---|---|
| 1 | `1-what-is-dapr` | What is Dapr | 3 | Style only. No Run blocks. Keep the sections and the overview image. Fix the typo "Currentely". Close with "What's next?" |
| 2 | `2-dapr-cli` | The Dapr CLI | 3 | Verification only, see below |
| 3 | `3-state-management-api` | Use the State Management API | 5 | Redis terminal → Dev Dashboard **State** page; Dapr sidecar terminal → **Dapr CLI** window |
| 4 | `4-service-invocation-api` | Use the Service Invocation API | 5 | Language tabs → Editor; anchored `cd`; the 2.0 run section |
| 5 | `5-pubsub-api` | Use the Pub/Sub API | 6 | As page 4, plus inspecting the subscription and publishing a message from the Dev Dashboard, and the final-page closing, with dapr-pubsub as the next track |

The total is 22 minutes, so the minutes line reads "around 20 minutes to complete the 5 labs". The
time limit is `30m` with `extend = "10m"`, and idle is `10m`. This is my call: today's track has a
45-minute limit for 25 estimated minutes, and once the install and init steps are gone it fits the
skill's default of 30. If you want to keep 45, change it.

Each page title is today's challenge `README.md` name, except page 2. "Dapr CLI" becomes "The Dapr
CLI" because the page no longer downloads anything. This is my call.

### Dev Dashboard

The pages use the Dev Dashboard tab (already in `layouts.hcl` and `tabs.hcl`) for four things:

| Use | Where | Pages |
|---|---|---|
| Check application health | **Applications** page, **Health** column (green dot), in the "Wait until … running" callout and in `## Before you start` | 3, 4, 5 |
| Inspect state records | **State** page: key, app prefix, value | 3 |
| Inspect the pub/sub subscription and publish a message | **Subscriptions** page: the subscription of `order-processor-sdk`, and publishing to `orderpubsub`/`orders` | 5 |
| Read app and sidecar logs | **Logs** page: select the app, search for a marker, and switch between the app's and the sidecar's logs | 3, 4, 5 |

- **Labels.** The pages are **Applications** (with the **Health** column), **State**,
  **Subscriptions** and **Logs**. The first three besides Subscriptions are already used by the live
  labs. The public docs (docs.diagrid.io, updated 2026-10-14) don't describe these pages, so before
  writing pages 3 to 5 the builder confirms, in the sandbox's Dev Dashboard
  (`dev_dashboard_version` in `modules/dapr-sandbox/versions.hcl`), the labels of the publish
  form's fields and button on the **Subscriptions** page, and how to switch between an app's logs
  and its sidecar's logs on the **Logs** page. Use the labels exactly as the UI shows them.
- Every dashboard step ends with "Then go back to the **Editor** tab" when the page continues in
  the Editor, as in the other labs.
- Dashboard steps are not commands, so doc-sync doesn't see them and CI can't click them. Where a
  step depends on something a suite can check, the suite checks it through the sidecar API instead
  (see Tests).

### Page 2: verification without install

- **Intro:** what the CLI is for (keep today's three bullets). Then say that the sandbox already has
  the Dapr CLI installed, and that `dapr init` already ran when the sandbox started. In this lab
  you'll check both.
- **Section 1, "The Dapr CLI":** the run-section IMPORTANT callout, then a `dapr -h` Run block in
  the **Dapr CLI** window with today's expected output. Then today's paragraph about the commands,
  reworded: you'll use `version` here and `run` in the next labs.
- **Section 2, "What `dapr init` did":** today's explanation of what initialization does (the
  sidecar binaries, Redis, Zipkin, placement, scheduler, the default components folder). Write it in
  the past tense. Name the command as inline code (`dapr init`) so learners know it for their own
  machine. Add one sentence that on your own machine you run it once after you install the CLI.
  There is no Run block and no copyable command block, and no `wget` install line.
- **Section 3, "Verify the Dapr version":** a `dapr --version` Run block. Show the expected output
  as `text,nocopy` with the literal pinned versions:
  - `CLI version: <dapr_cli_version>` from `modules/dapr-sandbox/versions.hcl`;
  - `Runtime version: <dapr_runtime_version>` from `dapr-101/versions.hcl`.

  2.0 has no `Instruqt-Var`. A pytest keeps these lines equal to the pins (see Tests).
- **Section 4, "Verify the containers":** a `docker ps --format {{.Names}}` Run block and today's
  list of the four containers. Remove the "Click the *Check* button" callout, because 2.0 has no
  checks.
- **Remove** the IMPORTANT callout about "read-only language tabs" and the email address. It
  describes the 1.0 layout. This is my call: the 2.0 labs carry no personal contact line.
- **No** `## Before you start`, because nothing runs before this page.

### Page 3: state without a Redis terminal

- The sidecar runs in the **Dapr CLI** window: `dapr run --app-id myapp --dapr-http-port 3500`.
  This needs no folder, so the page has no anchored `cd` (doc-sync only requires one before a
  relative `cd`).
- Open with `## Before you start` (check the Dev Dashboard and stop what runs). A learner who
  skipped back and forth may still have apps running.
- The two "Inspect the state using Redis CLI" steps become Dev Dashboard **State** page steps.
  After the save, find the record with the key `name` and the app prefix `myapp`, and expand it to
  see `"Bruce Wayne"`. Keep today's note that the key is prefixed with the app ID. After the
  delete, the record is gone from the page. The `redis-cli` commands go away (my call). The
  dashboard shows the same key and prefix with one terminal less, and the page has fewer commands
  that could drift.
- The save, get and delete curl commands, the IMPORTANT notes (regrade asides to `[!NOTE]` per the
  skill), stopping the sidecar, and `cat ~/.dapr/components/statestore.yaml` all stay. "Stop the
  Dapr process" becomes the `## N. Stop the applications` pattern. The component-file section stays
  after it, as it is today.
- After starting the sidecar, point to the Dev Dashboard **Applications** page, where `myapp` is
  listed. The sidecar's own log lines (such as `Component loaded: statestore (state.redis/v1)`)
  can be read on the **Logs** page as well as in the **Dapr CLI** window.

### Pages 4 and 5: apps from the demo repo

Each page:

1. `## Before you start`.
2. The inspection sections, unchanged in substance. "Use the language tab" becomes "Use the
   **Editor** tab and open `<folder>`". The `dapr.yaml` and `pubsub.yaml` snippets become
   `yaml,nocopy`, which also fixes today's `bash,nocopy` on page 4. Page 5 points to the component
   in the demo's `resources` folder, not a Components tab.
3. The run section:
   - the Run-button IMPORTANT callout;
   - `cd /root/ai-agent-tracks-instruqt/dapr-101`;
   - the "Run `dapr run -f .` from inside the demo folder" IMPORTANT callout;
   - one `<details>` per language, each with a relative `cd` into its folder, the install or build
     step, then `dapr run -f .` (`uv run dapr run -f .` for Python);
   - `###`, the "Wait until … running" IMPORTANT callout and the expected sidecar lines.

   Every command block becomes `bash,run` (not `bash,run,copy`). The pre-build makes the install
   and build steps fast. Keep them on the page anyway, so the page still works on a slow boot and
   learners see the real steps.
4. Expected app output: the same markers as today ("Order received" and "Order passed" on page 4,
   "Published data" and "Subscriber received" on page 5). Read them on the Dev Dashboard **Logs**
   page: select the app, search for the marker, then switch to the sidecar's logs for the same app.
   Fix page 5's ```` ```output ```` fence to `text,nocopy`.
5. Page 5 only, after the run: on the Dev Dashboard **Subscriptions** page, inspect the
   `order-processor-sdk` subscription to `orders` on `orderpubsub`. Then publish one message to
   that topic from the same page
   with an `Order` payload (for example `{"orderId": 100}`), and find "Subscriber received" for it
   on the **Logs** page. `checkout-sdk` is a console app that exits after its 10 messages, and
   `order-processor-sdk` keeps running, so the dashboard publish is the way to send one more
   message by hand.
6. A summary paragraph (keep today's), then `## N. Stop the applications`, `---` and "What's next?".
   Page 5 instead uses the final-page closing:
   - "In this final lab…" with the Holopin badge sentence in the intro;
   - the recap of the five labs;
   - "Collect your badge & provide feedback", keeping today's Holopin link `cmcnbdz1r295807jsdm16r929`
     and the badge image. The image stays at `dapr-101/5-pubsub-api/Diagrid-Dapr-Uni-101_x500.png`
     (my call): the live 1.0 track loads it from `main` by raw URL, so moving it would break the
     badge on the live track until the owner retires it. It's an image, not a 1.0 config file, so
     it doesn't conflict with "no 1.0 files left". Moving it to `images/` is a cleanup for after
     the retirement;
   - "Next steps", with dapr-pubsub replacing catalyst-101;
   - `<instruqt-completion>`.

## Demo apps (`ai-agent-tracks-instruqt/dapr-101/`)

Copy the apps from the committed `dapr/quickstarts` `master` (not from a local checkout with
uncommitted edits), and record the source commit in `dapr-101/README.md` in that repo:

- `service_invocation/{csharp,python,java,javascript}/http`;
- `pub_sub/{csharp,python,java,javascript}/sdk`;
- `pub_sub/components/pubsub.yaml`.

Layout. These are my calls, following the skill's naming rule:

```
dapr-101/
  dotnet/ServiceInvocation/{checkout,order-processor,dapr.yaml}
  dotnet/PubSub/{checkout,order-processor,dapr.yaml,resources/pubsub.yaml}
  python/service-invocation/…        python/pub-sub/…
  java/service-invocation/…          java/pub-sub/…
  javascript/service-invocation/…    javascript/pub-sub/…
```

- `csharp` becomes `dotnet`, so the folder names match the other labs.
- Each pub/sub demo gets its own `resources/` folder with `pubsub.yaml`. Its `dapr.yaml` changes
  `resourcesPath: ../../components/` to `resourcesPaths: ["./resources"]`. The page then explains
  "the `resources` folder of the demo".
- Python pub/sub: copy only the Flask `order-processor` that `dapr.yaml` runs. Change page 5's
  Python section from "two flavors" to that one app. This is my call: the FastAPI copy is never run
  and would confuse learners in the Editor. If you want to keep it, page 5 keeps its two-flavors
  text.
- **Retarget all four .NET projects to `net10.0`.** Upstream they target `net8.0`, and the image
  has only the .NET 10 SDK, so a net8.0 app won't run.
- Don't add a resiliency resource to the service invocation demo. Its `dapr.yaml` stays as page 4
  shows it today.
- Keep the app IDs, ports, log lines and loop counts unchanged, so the expected output on the pages
  stays true.

## Tests and CI

The shape of `dapr-pubsub`:

- **Suites:** one `tests/challenge.robot` per page. Page 1 gets a suite only if doc-sync needs it;
  today it has no runnable blocks, so like today, no suite.
  - Page 2: `dapr -h`, `dapr --version` asserted against the pins with
    `Assert Version Line Matches Minor` (or the exact version, as `dapr-pubsub` does), and the four
    containers. The doc-sync coverage comment for `wget` and `dapr init` goes away, because those
    commands are no longer on the page.
  - Page 3: today's suite. It keeps its `docker exec dapr_redis redis-cli KEYS '*'` assertions as
    the stand-in for the State page steps, so the `myapp||name` key the page describes is still
    tested.
  - Page 5 also checks the dashboard steps through the sidecar: the `orders` subscription of
    `order-processor-sdk` appears in its `/v1.0/metadata`, and publishing the page's example
    payload to `orderpubsub`/`orders` (with `curl` to `/v1.0/publish` on a running sidecar)
    produces "Subscriber received" for it. These checks are suite-only, not page commands.
  - Pages 4 and 5: today's per-language cases (tagged `dotnet`, `python`, `java`, `javascript`),
    pointed at `${DAPR101_BASE}` and run from the language's demo folder as the page does.
- `tools/track-tester/variables/dapr_101.py`:
  - `TRACKS_SRC_DIR` (falls back to `~/ai-agent-tracks-instruqt`);
  - `DAPR101_BASE`;
  - the demo folder names;
  - the existing markers;
  - drop `QUICKSTARTS_DIR`.
- `tools/track-tester/ci/setup-dapr-101.sh`, rewritten after `setup-dapr-pubsub.sh`:
  - read the pins with `read_pin.py`;
  - clone the demo repo at `tracks_src_ref`;
  - install the pinned CLI and init the pinned runtime. CI has no image, so the setup script still
    installs and inits. Only the learner-facing page drops those steps.
  - The 1.0 "deliberately unpinned" rationale goes away, because 2.0 pins both versions.
- `.github/workflows/test-dapr-101.yml`, rewritten after `test-dapr-pubsub.yml`:
  - a `changes` gate;
  - doc-sync with `--require-anchored-cd`;
  - matrix legs `dotnet`, `python`, `java`, `javascript` and `shared` (pages 2 and 3);
  - Maven pre-warm and Node setup;
  - the aggregate job `dapr-101-result`;
  - keep the `drift-report` job and the 06:00 schedule.
- `lab-validate.yml`: add `dapr-101` to the format, referenced-files, validate and shellcheck loops.
- `ci/tests/test_read_pin.py`: add `dapr-101/versions.hcl` and the lab to the parametrize lists.
- A pin-agreement pytest, like `test_pubsub_pins.py`:
  - `dapr-101`'s `dapr_runtime_version` equals `prewarm_dapr_runtime_version`;
  - the page 2 expected `CLI version:` and `Runtime version:` lines equal the pins.

## Repo housekeeping

- Delete from `dapr-101/`:
  - `README.md` (the 1.0 config);
  - `_setup/`;
  - every challenge `README.md` and `notes.md`;
  - `2-dapr-cli/scripts/check.sh` and `solve.sh`.

  An optional human `README.md` file map, like `dapr-secrets/README.md`, is allowed.
- `AGENTS.md`:
  - the track table row and the "2.0 labs" sentence (three labs now);
  - the required-checks list (`dapr-101-result`);
  - the CI table row;
  - the variables and `setup-dapr-101.sh` descriptions;
  - the doc-sync example path, if it changes.
- Repo `README.md`: the workflow table row.
- `legacy-1.0.md` and the skill's "older tracks" list: remove `dapr-101`.

## Left to the builder

- Exact wording of the reworded paragraphs, as long as it follows the skill and keeps today's
  meaning.
- The order of tasks and how the demo repo commit and this repo's PR are sequenced. The pin must
  point at a pushed commit.

## Hand-off (owner steps, after merge)

- Create the Instruqt 2.0 lab connected to `main`, root `dapr-101`, as in
  `docs/instruqt-2-runbook.md`.
- Add `dapr-101-result` to the required checks on `main`.
- Point the Dapr University `dapr-101` page at the new lab, then retire the 1.0 track. The 1.0
  track keeps running from Instruqt until then. Merging this removes its source files from `main`,
  so don't edit the 1.0 track after the merge.
