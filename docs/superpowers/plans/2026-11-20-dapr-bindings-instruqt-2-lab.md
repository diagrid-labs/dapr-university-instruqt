# Dapr Bindings Instruqt 2.0 Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `dapr-bindings`, a four-page Instruqt 2.0 lab on the four `university-labs/bindings` demos (cron input binding, PostgreSQL output binding, State API vs binding, bindings plus service invocation), with a sandbox image that has Postgres and warm caches, drift tests and CI.

**Architecture:** The lab copies the `dapr-pubsub` shape: HCL at the root, one folder per page with `assignment.md` and a Robot suite, no tasks. A sourceable `scripts/start-postgres.sh` (the `seed-vault.sh` pattern) starts `bindings-postgres` at boot through the module's `lab_startup_script` and in CI. The module image pre-pulls `postgres:18.7` and warms the bindings package caches; a new module version is published by the owner before the lab pins it.

**Tech Stack:** Instruqt 2.0 HCL + CLI, bash, Python 3.12 + pytest, Robot Framework, GitHub Actions, Dapr 1.19.1, PostgreSQL 18.7.

**Spec:** `docs/superpowers/specs/2026-11-19-dapr-bindings-instruqt-2-lab-design.md`

## Global Constraints

- Lab folder `dapr-bindings`; title `Dapr Bindings - Input and Output Bindings with Cron and PostgreSQL`.
- Time limit `30m`, extend `10m`, idle `10m`, `show_timer = true`, `show_warning = true`. Pages 6 / 8 / 7 / 7 = 28 minutes; `main.hcl` says "around 25 minutes to complete the 4 labs".
- Languages: .NET, Python, Java. No JavaScript.
- `dapr_runtime_version = "1.19.1"`; must equal `prewarm_dapr_runtime_version`.
- Demo repo `university-labs`, cloned to `/root/university-labs`; `editor_folder = "bindings"`; terminals' `working_directory = "/root/university-labs/bindings"`. `tracks_src_ref` = the `origin/main` SHA of `university-labs` at build time (now `99577e06afb30796a887e1ca150f0c91e284751d`).
- Postgres: image `postgres:18.7`, container `bindings-postgres`, `-p 127.0.0.1:5432:5432`, `POSTGRES_USER=dapr POSTGRES_PASSWORD=dapr POSTGRES_DB=dapr`, `bindings/sql` mounted read-only on `/docker-entrypoint-initdb.d`. Ready = `SELECT 1 FROM comms_log` succeeds.
- Ports: `engineering` 5201 / Dapr HTTP 3520; `subspace-beacon` 5202 / 3521.
- Folder names: .NET `Demo1-CronTrigger`, `Demo2-PostgresOutput`, `Demo3-StateVsBinding`, `Demo4-SubspaceBeacon` with apps `Engineering`, `SubspaceBeacon`; Python and Java `demo1-cron-trigger`, `demo2-postgres-output`, `demo3-state-vs-binding`, `demo4-subspace-beacon` with apps `engineering`, `subspace-beacon`.
- SQL in Run blocks: `docker exec bindings-postgres psql -U dapr -d dapr -c "<sql>"`, never `-it`.
- Module version `3.1.0` for `dapr-bindings` only; the other labs stay on `3.0.0`. No PR that pins `3.1.0` merges before the owner confirms it is published.
- No 1.0 files, no `tasks.hcl`, no check or solve scripts. No badge elements.
- Every page follows `.claude/skills/creating-dapr-university-tracks/SKILL.md` (page anatomy, run section, state carry-over) and the voice of `dapr-pubsub/2-streaming-subscriptions/assignment.md`.
- Each pin lives in one `variable "<name>" { default = "<value>" }` block, read with `tools/track-tester/ci/read_pin.py`.
- Never simplify `Stop Process With SIGINT`. Keep fence annotations and `# doc-sync coverage` blocks accurate.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Postgres was removed or restarted while `engineering` runs** (a learner runs page 2's restart block mid-demo). Expected: after the container is back, `stored reading` lines resume without restarting the app; if they don't, page 2 tells the learner to stop the apps first. Test in Task 4.
2. **Previous page's apps still running on 5201/3520** when a page's suite or learner starts. Expected: the suite fails fast with a "port in use" message; the page's "Before you start" says to `Ctrl+C`. `Ports Are Free` test in every page task.
3. **Page 1's schedule edit leaks into the checkout.** Expected: the suite edits a temporary copy only, and `git -C $TRACKS_SRC_DIR status --porcelain bindings` is empty after the suite. Test in Task 3.
4. **Languages mixed across pages** (Python on page 2, .NET on page 3): the `state` table keeps another language's rows. Expected: `/state/wc-0001` returns the reading the *current* app wrote (keys are overwritten). Test in Task 5 by running two languages in sequence and comparing.
5. **`start-postgres.sh` run twice** (CI re-run, VM re-boot, learner's restart block twice). Expected: rc 0 both times and both tables present. Test in Task 2 (pytest with a docker stub) and Task 4 (Robot, real container).

---

## File Structure

```
modules/dapr-sandbox/scripts/prewarm.sh     + postgres:18.7, + bindings caches
modules/dapr-sandbox/README.md              Postgres in the pre-pulled images
dapr-bindings/
  main.hcl pages.hcl layouts.hcl tabs.hcl versions.hcl website-description.md
  scripts/start-postgres.sh                 library: start_postgres <sql-dir>
  scripts/lab-setup.sh                      pre-build (detached), then start_postgres
  1-cron-input-binding/{assignment.md,tests/challenge.robot}
  2-postgres-output-binding/{assignment.md,tests/challenge.robot}
  3-state-vs-binding/{assignment.md,tests/challenge.robot}
  4-subspace-beacon/{assignment.md,tests/challenge.robot}
tools/track-tester/
  variables/dapr_bindings.py
  ci/setup-dapr-bindings.sh
  ci/tests/test_bindings_lab_setup.py       lab-setup + start-postgres behavior
  ci/tests/test_bindings_pins.py            postgres tag agreement
  ci/tests/test_read_pin.py                 + dapr-bindings in REAL_PINS and the prewarm parametrize; render test
.github/workflows/test-dapr-bindings.yml, lab-validate.yml
AGENTS.md, README.md, docs/instruqt-2-runbook.md
```

---

### Task 1: Image: Postgres and bindings caches

**Files:**
- Modify: `modules/dapr-sandbox/scripts/prewarm.sh`, `modules/dapr-sandbox/README.md`
- Test: `tools/track-tester/ci/tests/test_read_pin.py`

**Interfaces:**
- Produces: `PREWARM_IMAGES` contains `"postgres:18.7"`. After the pubsub warm loops, a bindings block warms (from `$PREWARM_DIR/repo`) `dotnet build` in `bindings/dotnet/Demo{1-CronTrigger,2-PostgresOutput,3-StateVsBinding,4-SubspaceBeacon}/Engineering` and `bindings/dotnet/Demo4-SubspaceBeacon/SubspaceBeacon`; `uv sync` and `mvn -q -DskipTests package` in the matching `bindings/{python,java}/demo*/engineering` folders and `demo4-subspace-beacon/subspace-beacon`.

- [ ] **Step 1: Failing test** `test_render_image_script_has_postgres_and_bindings`: render output contains `postgres:18.7`, `bindings/dotnet/Demo4-SubspaceBeacon/SubspaceBeacon`, `bindings/java/demo4-subspace-beacon/subspace-beacon`, `bindings/python/demo1-cron-trigger/engineering`; `bash -n` on it passes.
- [ ] **Step 2:** `(cd tools/track-tester && uv run pytest ci/tests/test_read_pin.py -v)` → the new test FAILs.
- [ ] **Step 3:** Edit `prewarm.sh` (update the image-list comment: "Postgres by the bindings lab") and the module README image list.
- [ ] **Step 4:** pytest → PASS. `shellcheck --shell=bash modules/dapr-sandbox/scripts/*.sh` → clean.
- [ ] **Step 5: Real build test:** `bash modules/dapr-sandbox/scripts/render-image-script.sh > "$SCRATCH/image.sh"` and run it in `ubuntu:24.04` as the pubsub plan's Task 3 Step 4 did. Expected: `docker images postgres:18.7` listed, the bindings builds succeed.
- [ ] **Step 6: Commit** `feat(modules): Postgres image and bindings caches in the sandbox image`

### Task 2: Lab skeleton, Postgres start, variables and CI setup

**Files:**
- Create: `dapr-bindings/{main.hcl,pages.hcl,layouts.hcl,tabs.hcl,versions.hcl,website-description.md}`, `dapr-bindings/scripts/{start-postgres.sh,lab-setup.sh}`, four `dapr-bindings/<n>-<slug>/assignment.md` holding only their H1, `tools/track-tester/variables/dapr_bindings.py`, `tools/track-tester/ci/setup-dapr-bindings.sh`, `tools/track-tester/ci/tests/test_bindings_lab_setup.py`, `tools/track-tester/ci/tests/test_bindings_pins.py`
- Modify: `.github/workflows/lab-validate.yml` (add `dapr-bindings` to the format and referenced-files loops, a `validate-lab.sh dapr-bindings modules/dapr-sandbox` line, the shellcheck `find`), `tools/track-tester/ci/tests/test_read_pin.py` (`REAL_PINS` entry and `test_prewarm_runtime_pin_matches_lab_runtime_pin` parametrize)

**Interfaces:**
- Produces:
  - `pages.hcl` resources `cron_input_binding`, `postgres_output_binding`, `state_vs_binding`, `subspace_beacon`, titled "Cron input binding", "PostgreSQL output binding", "State API vs binding", "Combining bindings with service invocation"; folders `1-cron-input-binding`, `2-postgres-output-binding`, `3-state-vs-binding`, `4-subspace-beacon`.
  - `main.hcl`: the `dapr-secrets` form with four learn bullets (input binding and route = component name; output binding `exec`/`query`; State API vs binding; bindings with service invocation), the minutes line, the 30 + 10 and idle lines, the art iframe, one chapter `bindings` titled "Dapr Bindings".
  - `tabs.hcl`, `layouts.hcl`: copies of `dapr-secrets` with the bindings folder.
  - `versions.hcl`: `dapr_runtime_version`, `tracks_src_ref`, `module "sandbox"` at `3.1.0` with `editor_folder = "bindings"` and `lab_startup_script = "${file("scripts/start-postgres.sh")}\n${file("scripts/lab-setup.sh")}"`, plus the publish-first comment from `dapr-pubsub/versions.hcl`.
  - `start-postgres.sh`: library, defines only `start_postgres <sql-dir>`. Runs the Global Constraints `docker run` after `docker rm -f bindings-postgres`, polls `docker exec bindings-postgres psql -U dapr -d dapr -tAc 'SELECT 1 FROM comms_log'` up to 60 times with `sleep 1`, returns 1 with `ERROR: Postgres did not create the bindings tables within 60 seconds.` on stderr. Uses no `log`/`die`/`bounded`, so CI can source it.
  - `lab-setup.sh`: `die`s if `$TRACKS_SRC_DIR/bindings` is missing; starts the detached pre-build (the `dapr-pubsub` heredoc pattern, log `/var/log/lab-prebuild.log`, spec `Demo1-CronTrigger:demo1-cron-trigger:Engineering:engineering`, … `Demo4-SubspaceBeacon:demo4-subspace-beacon:Engineering SubspaceBeacon:engineering subspace-beacon`); then `start_postgres "$TRACKS_SRC_DIR/bindings/sql" || die "Postgres for the bindings demos did not start"`; logs `done after ${SECONDS}s`.
  - `dapr_bindings.py`: `TRACKS_SRC_DIR` (as `dapr_pubsub.py`), `BINDINGS_BASE`, `DEMO1`..`DEMO4` and `ENGINEERING`, `SUBSPACE_BEACON` dicts keyed `dotnet`/`python`/`java`, `POSTGRES_IMAGE = "postgres:18.7"`, `POSTGRES_CONTAINER = "bindings-postgres"`, `PSQL = "docker exec bindings-postgres psql -U dapr -d dapr"`.
  - `setup-dapr-bindings.sh`: `setup-dapr-pubsub.sh` with `LAB_DIR=dapr-bindings`, then `source "$LAB_DIR/scripts/start-postgres.sh"; start_postgres "$TRACKS_SRC_DIR/bindings/sql"`.

- [ ] **Step 1: Failing tests.**
  - `test_bindings_lab_setup.py` (the `test_pubsub_lab_setup.py` style, `docker` stub on `PATH` that logs argv and answers the readiness `psql` with `1`):
    - `test_lab_startup_script_concatenates_start_postgres_and_lab_setup`: the `versions.hcl` text contains both `file(...)` calls in that order.
    - `test_lab_setup_runs_under_strict_mode`: concatenated script in the module's subshell → rc 0; the docker log has `rm -f bindings-postgres` before `run -d --name bindings-postgres` and contains `127.0.0.1:5432:5432` and `/bindings/sql:/docker-entrypoint-initdb.d:ro`.
    - `test_lab_setup_fails_without_the_bindings_folder` → rc != 0, stderr contains `bindings not found`.
    - `test_start_postgres_twice_succeeds` (Review Focus 5): source and call `start_postgres` twice → rc 0, two `rm -f` calls.
    - `test_start_postgres_times_out`: stub never answers the readiness query, loop count patched via `sleep` stub → rc 1 and the error message.
    - `test_start_postgres_needs_no_module_helpers`: `bash -c 'set -euo pipefail; source start-postgres.sh; start_postgres <dir>'` with no `log`/`die` defined → rc 0.
  - `test_bindings_pins.py::test_postgres_tag_matches_prewarm`: the `postgres:<tag>` in `start-postgres.sh`, `prewarm.sh` and `dapr_bindings.py` are equal.
- [ ] **Step 2:** `(cd tools/track-tester && uv run pytest ci/tests/test_bindings_lab_setup.py ci/tests/test_bindings_pins.py -v)` → FAIL. `tools/track-tester/ci/validate-lab.sh dapr-bindings modules/dapr-sandbox` → FAIL.
- [ ] **Step 3:** Write the files.
- [ ] **Step 4:** pytest (whole suite) → PASS. validate-lab → pass. `python3 tools/track-tester/ci/check_lab_paths.py dapr-bindings` → pass. `instruqt lab format dapr-bindings && git diff --exit-code` → clean. shellcheck clean. `bash tools/track-tester/ci/setup-dapr-bindings.sh` → completes, then `docker exec bindings-postgres psql -U dapr -d dapr -c '\dt'` lists `warp_core_readings` and `comms_log`.
- [ ] **Step 5: Commit** `feat(dapr-bindings): lab skeleton, Postgres start and CI setup`

### Tasks 3 to 6: one task per page

Every page task has the same shape; the table after the steps gives what differs. Facts, commands and expected output come from `university-labs/bindings/README.md` and the code; assertions mirror `university-labs/tests/bindings/smoke-demo<n>.sh`.

**Files (per page `<dir>`):**
- Modify: `dapr-bindings/<dir>/assignment.md`
- Create: `dapr-bindings/<dir>/tests/challenge.robot`, images only if the page needs a diagram

**Steps (per page):**

- [ ] **Step 1: Write `tests/challenge.robot`** in the shape of `dapr-pubsub/2-streaming-subscriptions/tests/challenge.robot`: `Ports Are Free Before The Apps Start` (5201, 3520, and 5202, 3521 on page 4), one test per language tagged `dotnet`/`python`/`java` (build, `Start Background Process  dapr run -f .`, `Wait Until App Responds http://localhost:5201/`, then a shared `Walk Through <Page>` keyword with `timeout=300s` for Java), and untagged shared tests for the SQL commands where they don't need a running app. Every `bash,run` command in the page appears literally in the suite; `cwd=` commands go into the trailing `# doc-sync coverage` block.
- [ ] **Step 2:** `(cd tools/track-tester && uv run robot --dryrun ../../dapr-bindings/<dir>/tests/challenge.robot)` → pass, then `uv run robot --outputdir results/<dir> ../../dapr-bindings/<dir>/tests/challenge.robot` → all three languages PASS. (The suite tests the demos; doc-sync ties it to the page in Step 4.)
- [ ] **Step 3: Write `assignment.md`** per the skill's page anatomy: H1 = `pages.hcl` title; intro ending "This hands-on lab takes about N minutes to complete."; `## Before you start` on pages 2 to 4; the run section (Run-button `[!IMPORTANT]`, anchored `cd /root/university-labs/bindings`, `dapr run -f .` `[!IMPORTANT]` with both folder spellings, page 1 only: the Editor port-popup `[!NOTE]`); one `<details>` per language for code to open and the `cd <demo> && dapr run -f .`; "Wait until … running" `[!IMPORTANT]` pointing at the Dev Dashboard; curl and SQL in the **curl** window outside `<details>`, JSON through `| jq` as `json,nocopy`, logs and psql output as `text,nocopy` with "your values will differ"; `## N. Stop the applications`; `---`; "What's next?".
- [ ] **Step 4:** doc-sync command from Step 2 → pass. Robot real run → pass. `check_lab_paths.py dapr-bindings` → pass.
- [ ] **Step 5: Commit** `feat(dapr-bindings): page <n> <title>`

| Task | Page dir | Min | Demo | Teaches and the learner's Run blocks | Suite asserts (beyond doc-sync coverage) |
|---|---|---|---|---|---|
| 3 | `1-cron-input-binding` | 6 | DEMO1 | What a binding is, input vs output. Open `resources/warp-core-scan.yaml` and the handler (no Dapr code). Run demo 1; read scan lines on the Dev Dashboard Logs page. Edit `@every 10s` → `@every 3s` in the Editor, restart, see faster scans; the page shows the full file as it should read afterwards. `[!NOTE]`: a failing handler is not retried and the schedule does not shift. | `engineering warp-core scan wc-0001` and `wc-0002` in the log. Schedule test: copy the demo folder to `${TEMPDIR}`, `sed` the schedule to `@every 3s`, run, expect `wc-0004` within 20 s of `wc-0001`. After the suite, `git -C ${TRACKS_SRC_DIR} status --porcelain bindings` is empty (Review Focus 3). |
| 4 | `2-postgres-output-binding` | 8 | DEMO2 | Where Postgres comes from (the `docker run` as `text,nocopy`, a `\dt` Run block, and a `### If the database is not running` subsection with the restart-safe `docker run` + readiness loop as a Run block, mounting `/root/university-labs/bindings/sql`). Pages 3 and 4's "Before you start" add one line: if `bindings-postgres` is not in `docker ps`, use that subsection on page 2. Open `../resources/ship-db.yaml` and `dapr.yaml` `resourcesPaths`. Run demo 2. `curl -s "http://localhost:5201/readings?minTemp=900" \| jq`. `SELECT * FROM warp_core_readings;`. Open the `query` code: array of arrays, `sql` and `params` metadata. `purged old readings`; re-run the SELECT after a minute. | `engineering cleared warp_core_readings for a fresh run`, `engineering stored reading wc-0001 in warp_core_readings`; `/readings?minTemp=-5` contains `wc-0001` with keys `readingId, stardate, coreTempK, plasmaFlow, recordedAt`; `/readings?minTemp=abc` → 400 `INVALID_MIN_TEMP`; aged-row purge as `smoke-demo2.sh` (insert a 2-minute-old row, wait ≤ 45 s for a new `purged old readings`, row gone). Restart block run twice → rc 0 (Review Focus 5). Extend `test_postgres_tag_matches_prewarm` with the `postgres:` tag in this page's restart block. Restart block while demo 2 runs → a new `stored reading` line within 30 s (Review Focus 1; if it fails, change the page to stop the apps first and assert that instead). |
| 5 | `3-state-vs-binding` | 7 | DEMO3 | Open `resources/statestore.yaml` (same database, `state.postgresql`). Run demo 3. `curl -s http://localhost:5201/state/wc-0001 \| jq` and `/readings?minTemp=900`. `\d state`, `\d warp_core_readings`, `SELECT key, value FROM state LIMIT 2;`. Dapr owns `state` and prefixes `engineering\|\|`; the comparison table; "when to use which". | `engineering saved reading wc-0001 to statestore (key=reading-wc-0001)`; `/state/wc-0001` equals the reading in the scan log line; `/state/nope` → 404 `NOT_FOUND`; `\d state` output contains `key`, `value`, `jsonb`; `SELECT key FROM state` contains `engineering\|\|reading-wc-0001`. Review Focus 4: after the dotnet and python tests ran in sequence, the python test's `/state/wc-0001` matches the python scan line. |
| 6 | `4-subspace-beacon` | 7 | DEMO4 | Two apps; open `resources/beacon-ping.yaml` (why `scopes`) and the `engineering` handler's three steps per language (service invocation by app ID, `exec` into `comms_log`, log). Run demo 4. `curl -s http://localhost:5202/ping \| jq` (and that it advances the sequence). `curl -s http://localhost:5201/comms/status \| jq` until `ESTABLISHED`. `SELECT * FROM comms_log;`. Final page closing: recap one line per page, "Feedback and further learning", *Next steps* (Dapr bindings docs, the secrets track for `secretKeyRef`), `<instruqt-completion>`. | `engineering cleared comms_log for a fresh run`; `signalStrength=94 message="channel open"` in the log; `/comms/status` contains `"status":"ESTABLISHED"` within 90 s (Java 180 s); `SELECT count(*) FROM comms_log` ≥ 6; the beacon's sidecar metadata (3521) does not list `beacon-ping`. |

### Task 7: CI workflow

**Files:**
- Create: `.github/workflows/test-dapr-bindings.yml`
- Modify: `README.md` (workflow table row)

**Interfaces:**
- Produces: required-check name `dapr-bindings-result`.

- [ ] **Step 1:** Copy `test-dapr-pubsub.yml`. Change: name; `cron: '15 7 * * *'` with the staggering comment (after dapr-pubsub 07:00); the `changes` filter (`dapr-bindings/**`, `modules/dapr-sandbox/**`, `tools/track-tester/**`, the workflow file); the doc-sync loop and `challenges` list (`1-cron-input-binding:ch1 2-postgres-output-binding:ch2 3-state-vs-binding:ch3 4-subspace-beacon:ch4`); `setup-dapr-bindings.sh`; `read_pin.py dapr-bindings/versions.hcl tracks_src_ref`; the Maven cache key `maven-daprbindings-${{ hashFiles('university-labs/bindings/java/**/pom.xml') }}` and the pre-warm over `$TRACKS_SRC_DIR/bindings/java`; every `dapr-pubsub` name in artifacts, report text and the aggregate job → `dapr-bindings`.
- [ ] **Step 2:** `uvx actionlint .github/workflows/test-dapr-bindings.yml` → clean. `grep -n pubsub .github/workflows/test-dapr-bindings.yml` → nothing.
- [ ] **Step 3:** Push the branch; run the workflow with `workflow_dispatch` → doc-sync and all four legs green.
- [ ] **Step 4: Commit** `ci(dapr-bindings): daily drift tests`

### Task 8: Docs and owner hand-off

**Files:**
- Modify: `AGENTS.md` (tracks table row; the 2.0 lab lists; `lab_startup_script` example list; required checks add `dapr-bindings-result`; CI table row 07:15; directory map `dapr_bindings.py`, `setup-dapr-bindings.sh`, `test_bindings_lab_setup`, `test_bindings_pins`; "Only … have track-tester suites" sentence), `docs/instruqt-2-runbook.md` (section "Module 3.1.0 / dapr-bindings" with the owner steps below; the module-version row now lists `dapr-bindings/versions.hcl`)

- [ ] **Step 1:** Edit. `grep -n "dapr-pubsub" AGENTS.md` and check each list that names the 2.0 labs also names `dapr-bindings`.
- [ ] **Step 2:** `(cd tools/track-tester && uv run pytest -v)` → pass (some tests read AGENTS.md-adjacent files).
- [ ] **Step 3: Commit** `docs: dapr-bindings lab`

### Checkpoint: owner

Write these into the runbook section from Task 8, then hand off. Do not merge the branch before step 2 is done.

1. Build the image from `render-image-script.sh`, set `image_ref` in `modules/dapr-sandbox/versions.hcl` on the branch, publish module `3.1.0`.
2. Confirm the publish; then merge.
3. In Instruqt, create the `dapr-bindings` lab from branch `main`, root directory `dapr-bindings`.
4. Add `dapr-bindings-result` to the required checks on `main`.
5. Live start: record `grep 'done after' /var/log/lab-setup.log` and compare with a `dapr-pubsub` start (spec risk: more than about 15 s extra → move `start_postgres` into the background and have page 2 wait for it). `docker ps` shows `bindings-postgres`; `docker events` or the setup log shows no `postgres` pull.
6. Live run all four pages in one language with a timer: under 30 minutes, no build waits; skip page 2 once and check pages 3 and 4 still work.
7. Add the track to Dapr University with `website-description.md`; supply a badge if there is one.
