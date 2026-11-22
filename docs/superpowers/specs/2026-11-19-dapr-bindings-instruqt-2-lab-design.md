# Dapr Bindings as an Instruqt 2.0 lab

Status: draft, 2026-11-19.

## Why

Dapr University has no track about bindings. The demo apps already exist in
`diagrid-labs/university-labs` under `bindings/`: four demos, each in .NET, Python and Java, with
smoke tests in `tests/bindings/`. They were merged to `main` in PR #13 (merge commit `99577e0`).
This project turns them into a lab.

The demos tell one story. A starship's **engineering** console logs warp-core readings on a
schedule and pings a **subspace beacon** to open a communications channel. On the way, the learner
uses both directions of a binding: a cron **input** binding (Dapr calls the app) and a PostgreSQL
**output** binding (the app asks Dapr to run SQL). The PostgreSQL binding is output-only, so cron
supplies the input side.

`dapr-pubsub` and `dapr-secrets` are the reference labs for structure, voice and tests. The
`creating-dapr-university-tracks` skill (and its `reference.md`) describes them and is the
checklist for this build.

## Goals

- A new Instruqt 2.0 lab, `dapr-bindings/`, with four pages, one per demo, in .NET, Python and Java.
- 30 minutes in total, 10 minutes extra, 10 minutes idle timeout (the default from `dapr-secrets`).
- The learner can explain, after the track:
  - what an input binding is and that the component name is the route, with no Dapr code in the app;
  - what an output binding is, and the `exec` and `query` operations of the PostgreSQL binding;
  - when to use the State API and when to use a binding against the same database;
  - how bindings combine with other building blocks (service invocation) in one flow.
- Drift tests for every page and a CI workflow with the same guarantees as `dapr-pubsub`: doc-sync
  with `--require-anchored-cd`, a `changes` path filter, a `shared` leg, and an aggregate required
  check `dapr-bindings-result`.
- No cold builds and no image pulls on the learner's clock.

## Non-goals

- No changes to the demo apps unless a page cannot be written without one. If that happens, the
  fix goes upstream first and the lab pins the new commit.
- No JavaScript. The demos exist in .NET, Python and Java only.
- No other binding types (Kafka, HTTP, blob storage, SMTP and so on), no Kubernetes, no Catalyst.
- No secret references in the components. The `ship-db` connection string is a plain local
  credential; the component comments already point to the secrets track for `secretKeyRef`.
- No changes to `dapr-101`, `dapr-secrets` or `dapr-pubsub` beyond what the shared module needs.
  They may stay on module `3.0.0`.
- No 1.0 files (`README.md` config, `_setup/`, `tabs.md`, `notes.md`, `tasks.hcl`, check or solve
  scripts).

## Anti-goals (a failure even if it technically works)

- Pages that read like `bindings/README.md` pasted in. That README is reference material for
  running the demos locally. The pages use the `dapr-pubsub` voice: short sentences, one idea per
  step, the *why* after each observation.
- A learner waiting on a `postgres` image pull, a cold Maven download or a NuGet restore.
- A Run block that leaves a terminal stuck in an interactive `psql` session.
- A page that breaks when the learner skipped the previous page or left apps running.

## Current state

- `university-labs/bindings` at `99577e0` (newest `main` now):
  - `<lang>/resources/ship-db.yaml`: the shared `bindings.postgresql` component, `direction: output`,
    connection string `host=localhost port=5432 user=dapr password=dapr dbname=dapr`.
  - Demo 1 `Demo1-CronTrigger` / `demo1-cron-trigger`: cron component `warp-core-scan`
    (`@every 10s`), `POST /warp-core-scan`. No Postgres. Loads only its own `resources/`.
  - Demo 2 `Demo2-PostgresOutput` / `demo2-postgres-output`: each tick stores a reading with
    `exec`; `GET /readings?minTemp=` reads them with `query`; cron `purge-old-readings`
    (`@every 30s`) deletes rows older than one minute.
  - Demo 3 `Demo3-StateVsBinding` / `demo3-state-vs-binding`: each reading is saved through the
    State API (`state.postgresql`, component `statestore`) and through `ship-db`.
    `GET /state/<readingId>` and `GET /readings`.
  - Demo 4 `Demo4-SubspaceBeacon` / `demo4-subspace-beacon`: two apps. Cron `beacon-ping`
    (`@every 5s`, scoped to `engineering`) makes `engineering` call `subspace-beacon` by service
    invocation and insert the answer into `comms_log`. `GET /comms/status` turns from `SEARCHING`
    to `ESTABLISHED` after about 30 seconds.
  - Ports, the same in every language: `engineering` 5201 / Dapr HTTP 3520, `subspace-beacon`
    5202 / 3521, Postgres 5432. None of them clash with the Editor (8888) or Dev Dashboard (9090).
  - Folder names: PascalCase for .NET (`Demo1-CronTrigger/Engineering`), kebab-case for Python and
    Java (`demo1-cron-trigger/engineering`). Java uses Spring Boot 4.0.8, as the pubsub demos do.
  - Demos 2 to 4 clear their own table at startup and log
    `engineering cleared <table> for a fresh run`, so state left over from an earlier page or
    language does not leak into results.
  - Postgres: `postgres:18.7`, container `bindings-postgres`, bound to `127.0.0.1:5432`,
    `bindings/sql/init.sql` mounted into `/docker-entrypoint-initdb.d` (creates
    `warp_core_readings` and `comms_log`). The README's readiness loop waits for the table, not for
    `pg_isready`, because the init script runs after the first "ready".
  - `tests/bindings/smoke-demo<n>.sh` check every demo in every language. They are the best source
    for what the drift suites should assert and for the timing (purge, `ESTABLISHED`).
- `modules/dapr-sandbox` `3.0.0` (image `diagrid/dapr-sandbox-4:v1`): `prewarm.sh` pulls the Dapr,
  Redis, Zipkin, Vault and RabbitMQ images and warms the package caches for the secrets and pubsub
  demos. It has no `postgres` image and no warm caches for the bindings demos.

## Target design

### Part A: module and image

The sandbox image lacks two things this lab needs, so this is a module change and an owner step:

- `prewarm.sh` pulls `postgres:18.7`.
- `prewarm.sh` warms the package caches for every bindings app: `dotnet build` for the four
  `Engineering` apps and `Demo4-SubspaceBeacon/SubspaceBeacon`, `uv sync` and
  `mvn -q -DskipTests package` for the matching Python and Java folders.

Rebuild the image, publish a new module version and pin it in `dapr-bindings/versions.hcl` only.
No interface change, so a minor version (`3.1.0`) is enough (my call). The other labs can move to
it later; that is not part of this project.

A check (pytest in `lab-validate`, as `test_pubsub_pins` does for RabbitMQ) asserts that the
`postgres` tag in `prewarm.sh` equals the tag the lab starts, so the pre-pull cannot silently stop
helping.

**Order of delivery:** the lab is built and tested against the local module copy
(`validate-lab.sh`). No PR that pins the new module version merges before the owner confirms the
version is published in Instruqt.

### Part B: the `dapr-bindings` lab

**Layout** (copied from `dapr-pubsub`, minus the `broker` layout and the RabbitMQ tab):

```
dapr-bindings/
  main.hcl  pages.hcl  layouts.hcl  tabs.hcl  versions.hcl
  website-description.md
  scripts/lab-setup.sh            pre-build + start Postgres
  scripts/start-postgres.sh       sourceable: start bindings-postgres and wait for the tables
  1-cron-input-binding/           assignment.md, tests/challenge.robot
  2-postgres-output-binding/
  3-state-vs-binding/
  4-subspace-beacon/
```

**`main.hcl`:** title "Dapr Bindings - Input and Output Bindings with Cron and PostgreSQL" (my
call, the user may rename). A "you'll learn" list with four bullets, "around 25 minutes to complete
the 4 labs" (28 rounded down), the 30 + 10 minutes and idle lines, the sandbox art iframe. No badge
lines until the user supplies a badge. One chapter, four pages.

**`versions.hcl`:** `dapr_runtime_version = "1.19.1"`, `tracks_src_ref` = the newest
`university-labs` `main` commit when the lab is built (now `99577e0`), the module block at the new
version with `editor_folder = "bindings"` and
`lab_startup_script = "${file("scripts/start-postgres.sh")}\n${file("scripts/lab-setup.sh")}"`
(the `dapr-secrets` pattern with `seed-vault.sh`).

**Tabs and layout:** the same as `dapr-secrets`: Editor and Dev Dashboard on top, **Dapr CLI** and
**curl** terminals side by side below. The terminals' `working_directory` and the Editor folder are
`/root/university-labs/bindings`.

**Postgres is started at boot** by `lab-setup.sh`, through `start-postgres.sh` (my call). Three of
the four pages need it, and learners can skip pages, so starting it from page 2 would mean a
restart block on pages 2, 3 and 4. Booting it is the `dapr-secrets` Vault pattern. The demo
README already says "In Instruqt the sandbox setup script prepares everything below for you".
`start-postgres.sh` uses the README's command (remove first, bind `127.0.0.1:5432`, mount
`$TRACKS_SRC_DIR/bindings/sql`) and its readiness loop, bounded, and `die`s if the tables never
appear. CI sources the same file, so the command lives in one place. Like `seed-vault.sh`, it
works both inside the module startup (where `log`, `die` and `bounded` exist) and in CI (where
they don't).

Page 2 has a short section on where the database comes from: one `text,nocopy` view of the
`docker run` command, and a Run block that lists the tables, so a learner can see it is up. If a
learner removed the container, page 2 gives a restart-safe Run block (`bash` of
`start-postgres.sh` is not available on the VM, because the lab's files are not on it, so this
block repeats the `docker run` from the README; the pin test above covers its tag too).

**SQL from Run blocks is non-interactive:**
`docker exec bindings-postgres psql -U dapr -d dapr -c "SELECT ..."` in the **curl** window,
instead of the README's `docker exec -it ... psql` (my call: a Run button that opens an
interactive shell leaves the terminal stuck, and doc-sync and the suites need a plain command).
A `[!NOTE]` tells the learner they can open an interactive `psql` with `-it` if they want to
explore.

**Each page** follows the skill's page anatomy: H1 equal to the `pages.hcl` title, intro ending
"This hands-on lab takes about N minutes to complete.", `## Before you start` on pages 2 to 4
(check the Dev Dashboard, stop running apps with `Ctrl+C`), numbered `## N.` sections, the run
section with the Run-button `[!IMPORTANT]`, the anchored `cd /root/university-labs/bindings`, the
`dapr run -f .` `[!IMPORTANT]` with both folder spellings, one `<details>` per language for opening
code, the "Wait until … running" `[!IMPORTANT]` pointing at the Dev Dashboard, `## N. Stop the
applications`, `---`, and a "What's next?" paragraph. Everything that is the same in every language
(curl, SQL, expected output, YAML) stays outside the `<details>` blocks. JSON through `| jq`, shown
as `json,nocopy`.

**Page content** (the facts come from the upstream README and code; the builder writes the prose):

| # | Page (folder) | Min | What the learner does and sees |
|---|---|---|---|
| 1 | Cron input binding (`1-cron-input-binding`) | 6 | What a binding is, and input vs output. Opens `resources/warp-core-scan.yaml` and the handler. Runs Demo 1 and reads the scan lines in the Dev Dashboard Logs page. Learns that the component name is the route and that the app holds no Dapr code for it. Edits the schedule to `@every 3s` in the Editor, restarts, sees faster scans; the page states what the file should read afterwards. A `[!NOTE]` on the README's resilience finding: a failing handler is not retried and the schedule does not shift. |
| 2 | PostgreSQL output binding (`2-postgres-output-binding`) | 8 | Where the database comes from, and a table list. Opens `../resources/ship-db.yaml` and the `dapr.yaml` `resourcesPaths` (shared plus own folder). Runs Demo 2, sees `stored reading` lines. `curl` `/readings?minTemp=900`, then `SELECT` from `warp_core_readings`. Opens the `query` code and sees the array-of-arrays answer and the `sql` / `params` metadata. Sees `purged old readings` and, after a minute, the oldest rows gone. |
| 3 | State API vs binding (`3-state-vs-binding`) | 7 | Runs Demo 3. `curl` `/state/wc-0001` and `/readings`. `\d state`, `\d warp_core_readings` and `SELECT key, value FROM state LIMIT 2`. Sees that Dapr owns `state` and prefixes keys with `engineering||`, and that `warp_core_readings` has the schema the learner chose. Ends with the README's comparison table and a one-paragraph "when to use which". |
| 4 | Combining bindings with service invocation (`4-subspace-beacon`) | 7 | Two apps. Opens `beacon-ping.yaml` (and why it has `scopes`) and the `engineering` handler's three steps. Runs Demo 4. Watches the signal firm up in the logs, `curl` `/comms/status` until `ESTABLISHED`, `SELECT` from `comms_log`. Closes the track. |

Total: 28 minutes, shown as "around 25 minutes".

Expected output blocks copy real values from the README and say that readings, stardates and IDs
will differ.

**Final page closing:** as in `dapr-pubsub` page 6: a recap with one line per page, "Feedback and
further learning", the *Next steps* groups (pointing to the Dapr bindings docs and the secrets track
for `secretKeyRef`), and `<instruqt-completion>`. No Holopin badge until the user supplies one.

**Pre-build (`scripts/lab-setup.sh`):** a detached background job, as in `dapr-pubsub`, that builds
every bindings app in all three languages, demo 1 first, logs to `/var/log/lab-prebuild.log`, and
never fails the lab.

### Part C: tests and CI

- `tools/track-tester/variables/dapr_bindings.py`: `TRACKS_SRC_DIR` (same env var and fallback as
  `dapr_pubsub.py`), `BINDINGS_BASE`, a `DEMO<n>` dict per demo with the folder names per
  language, and the log markers.
- `tools/track-tester/ci/setup-dapr-bindings.sh`: the `setup-dapr-pubsub.sh` shape (pins via
  `read_pin.py`, clone at `tracks_src_ref`, `dapr-init.sh`), and then sources
  `dapr-bindings/scripts/start-postgres.sh`.
- One `tests/challenge.robot` per page: a test case per language tagged `dotnet`, `python`,
  `java`, and untagged shared tests for language-free steps (the SQL commands). Assertions follow
  `tests/bindings/smoke-demo<n>.sh`. Page 1 tests the schedule edit on a temporary copy of the
  demo folder, never on the checkout. Each suite stops its apps with `Stop Process With SIGINT`.
- `.github/workflows/test-dapr-bindings.yml`: the `test-dapr-pubsub.yml` structure (changes
  filter, doc-sync with `--require-anchored-cd`, matrix `dotnet`, `java`, `python`, `shared`,
  `failed-<leg>.txt`, `drift-report` issue, aggregate `dapr-bindings-result`). Daily at 07:15 UTC.
- `lab-validate.yml`: add `dapr-bindings` to the format, `check_lab_paths.py`, validate and
  shellcheck loops. Add the lab to the parametrize lists in `ci/tests/test_read_pin.py`, and add
  the postgres tag pin test.

### Docs to update

- `AGENTS.md`: the track table, the 2.0 lab list, the required checks, the CI workflow table, the
  directory map (`dapr_bindings.py`, `setup-dapr-bindings.sh`).
- The repo `README.md` workflow table.
- `modules/dapr-sandbox/README.md`: Postgres in the pre-pulled images.

## Owner steps (pending, outside the repo)

From `docs/instruqt-2-runbook.md`: build the image and publish the module version before the pin
merges; create the `dapr-bindings` lab in Instruqt connected to `main` with root directory
`dapr-bindings`; add `dapr-bindings-result` to the required checks on `main`; do a live run; add
the track to Dapr University with `website-description.md`; supply a badge if there is one.

## Success criteria

- All four suites green in all three languages, doc-sync green, `lab-validate` green.
- A live start where `bindings-postgres` is up with both tables when the sandbox reports ready,
  and the `docker run` of `postgres:18.7` did not pull.
- A live run through all four pages in one language within 30 minutes with no waits on builds.
- Each page works when the previous page was skipped, and when the previous page's apps are still
  running (after the learner follows "Before you start").

## Risks to spike first

- **Boot time.** Starting Postgres and waiting for the init script adds to the time before the
  sandbox is ready. Measure the `done after Ns` line in `/var/log/lab-setup.log` against
  `dapr-pubsub`. If it adds more than about 15 seconds, start the container in the background and
  have page 2 wait for it instead.
- **Demo 4 timing in CI.** `ESTABLISHED` needs about 30 seconds of pings after both apps are up;
  Java start-up is slow. Use the smoke test's timeouts as the floor.
- **Purge timing on page 2.** A row needs to be over one minute old and then hit a 30-second tick.
  The page tells the learner to wait; the suite inserts an aged row, as the smoke test does.

## Left to the builder

- Exact page titles and slugs (the table above is the intent), and the prose.
- The module version number, if `3.1.0` is not the next free one.
- The wording of the "you'll learn" bullets and `website-description.md`.
- Which assertions are shared tests and which are per language.
- Whether the Java legs need longer timeouts than `dapr-pubsub`.
