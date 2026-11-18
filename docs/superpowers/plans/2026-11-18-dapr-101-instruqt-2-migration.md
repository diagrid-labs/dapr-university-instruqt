# dapr-101 Instruqt 2.0 Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `dapr-101/` into an Instruqt 2.0 lab on the shared `diagrid/dapr-sandbox` module. It
keeps the same five pages and four languages, the demo apps come from
`ai-agent-tracks-instruqt/dapr-101/`, page 2 only verifies the preinstalled CLI and `dapr init`,
the Dev Dashboard handles inspection, and page 5 suggests dapr-pubsub as the next track.

**Architecture:** Copy `dapr-pubsub` and `dapr-secrets`:

- HCL root files;
- a `lab-setup.sh` that only pre-builds;
- one `assignment.md` and one Robot suite per page;
- a variables file, a CI setup script and a gated workflow with an aggregate result job.

The demo apps go into the separate demo repo first, and this lab pins that commit. A structural
pytest (`test_dapr101_pages.py`) checks the page rules the drift suites can't see, and a pin pytest
keeps page 2's version lines equal to the pins.

**Tech Stack:**

- Instruqt 2.0 HCL;
- Bash;
- Robot Framework 7 and pytest (via `uv`, run from `tools/track-tester/`);
- GitHub Actions;
- the demo apps: .NET 10, Python with uv, Java 17 with Maven, Node 24.

**Spec:** `docs/superpowers/specs/2026-11-18-dapr-101-instruqt-2-migration-design.md`. Read it
before Task 1. It is the authority wherever this plan is silent.

**Skill:** `.claude/skills/creating-dapr-university-tracks/` (`SKILL.md`, `reference.md`). It owns
the page anatomy, the callout wording and the CI shape. Follow it.

## Global Constraints

- Five pages, four languages (.NET, Python, Java, JavaScript), test tags `dotnet`, `python`,
  `java`, `javascript`.
- Lab folder on the VM: `/root/ai-agent-tracks-instruqt/dapr-101`. Both terminals use it as
  `working_directory`, and `editor_folder = "dapr-101"`.
- `main.hcl` timelimit `30m` with extend `10m`, idle `10m`. Minutes line: "You'll probably need
  around 20 minutes to complete the 5 labs."
- Page minutes: 3, 3, 5, 5, 6.
- `dapr_runtime_version` and the module version are the same as `dapr-pubsub/versions.hcl` (today
  `1.19.1` and `2.0.0`).
- Page 2 contains no Run block or copyable block with `dapr init` or the CLI install script, and
  no `Instruqt-Var`.
- Page 5 "Try another university track" lists Dapr Workflow
  (`https://www.diagrid.io/university/dapr-workflow`) and Dapr Pub/Sub
  (`https://www.diagrid.io/university/pubsub`). It doesn't list catalyst-101.
- Badge: keep the Holopin link `https://holopin.io/collect/cmcnbdz1r295807jsdm16r929` and the image
  at its current path `dapr-101/5-pubsub-api/Diagrid-Dapr-Uni-101_x500.png`. Don't move it.
- Dev Dashboard page labels: **Applications** (**Health** column), **State**, **Subscriptions**,
  **Logs**.
- Demo folders in the demo repo, under `dapr-101/`:
  - `dotnet/ServiceInvocation` and `dotnet/PubSub`;
  - `python/service-invocation` and `python/pub-sub`;
  - `java/service-invocation` and `java/pub-sub`;
  - `javascript/service-invocation` and `javascript/pub-sub`.
- Copy the demos from committed `dapr/quickstarts` `origin/master` (`a7aab420` at planning time;
  use the current `origin/master` and record its full SHA). Never copy from the local checkout's
  working tree, which has uncommitted edits.
- All .NET projects target `net10.0`. App IDs, ports, log lines and loop counts don't change.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Don't push this repo's branch, merge anything, or touch Instruqt without asking the user.
  Pushing the demo repo branch in Task 1 is allowed, because the pin must point at a pushed
  commit; that's the one push this plan makes.

## Review Focus

1. **State left over from an earlier page.** A learner who reaches page 3, 4 or 5 with a sidecar
   or apps still running (ports 3500, 7001/6001/5001/8080 and so on) is told to check the Dev
   Dashboard and stop them. Pinned by `test_dapr101_pages.py::test_before_you_start` and
   `::test_stop_section`.
2. **A slow boot.** A learner who clicks Run before the background pre-build has finished still
   gets a working build, because pages 4 and 5 keep the install and build commands. Pinned by
   doc-sync (each command must be in the suite) and the suites running those commands from a clean
   clone.
3. **The Python pub/sub workspace after the FastAPI app is removed.** `uv sync --all-packages`
   from a fresh clone must succeed without re-locking. Pinned in Task 1 Step 6 with
   `uv sync --locked --all-packages`.
4. **The .NET 10-only image.** No project may still target `net8.0`. Pinned in Task 1 Step 6 with
   a grep that must return nothing.
5. **A pin bump without a page update.** When `dapr_cli_version` or `dapr_runtime_version`
   changes, page 2's expected `dapr --version` output must change with it. Pinned by
   `test_dapr101_pins.py`.

---

## File map

**Demo repo** (`../ai-agent-tracks-instruqt`, branch `dapr-101-demos`):
`dapr-101/README.md` and the eight demo folders listed above.

**This repo:**

| Path | Action | Responsibility |
|---|---|---|
| `dapr-101/main.hcl`, `pages.hcl`, `layouts.hcl`, `tabs.hcl`, `versions.hcl` | Create | Lab config |
| `dapr-101/scripts/lab-setup.sh` | Create | Background pre-build of the demo 4 and 5 apps |
| `dapr-101/website-description.md` | Create | Site prose |
| `dapr-101/<n>-<slug>/assignment.md` | Rewrite | Pages |
| `dapr-101/{2,3,4,5}-*/tests/challenge.robot` | Rewrite | Drift suites |
| `dapr-101/README.md`, `_setup/`, `*/README.md`, `*/notes.md`, `2-dapr-cli/scripts/` | Delete | 1.0 files (the root `README.md` may come back as a file map) |
| `tools/track-tester/variables/dapr_101.py` | Rewrite | `TRACKS_SRC_DIR`, `DAPR101_BASE`, demo dicts, markers |
| `tools/track-tester/ci/setup-dapr-101.sh` | Rewrite | Reproduce the lab in CI |
| `tools/track-tester/ci/tests/test_dapr101_pages.py` | Create | Structural page rules |
| `tools/track-tester/ci/tests/test_dapr101_pins.py` | Create | Page 2 version lines equal the pins |
| `tools/track-tester/ci/tests/test_read_pin.py` | Modify | Add `dapr-101` to `REAL_PINS` and the prewarm parametrize list |
| `.github/workflows/test-dapr-101.yml` | Rewrite | Gated CI with `dapr-101-result` |
| `.github/workflows/lab-validate.yml` | Modify | Add `dapr-101` to the four loops |
| `AGENTS.md`, `README.md`, `.claude/skills/creating-dapr-university-tracks/{SKILL.md,legacy-1.0.md}` | Modify | Docs |

---

### Task 1: Demo apps in ai-agent-tracks-instruqt

**Files (demo repo `../ai-agent-tracks-instruqt`):**
- Create: `dapr-101/README.md`
- Create: `dapr-101/{dotnet,python,java,javascript}/…` (the eight folders)

**Interfaces:**
- Produces:
  - **`DEMO_SHA`**: the pushed commit of `dapr-101-demos`, used as `tracks_src_ref` in Task 2.
  - **The folder layout.** Each folder holds `checkout/`, `order-processor/` and `dapr.yaml`.
    Each pub/sub folder also holds `resources/pubsub.yaml`.
  - **Python workspaces.** `pyproject.toml` and `uv.lock` sit at each Python demo root.

- [ ] **Step 1: Branch the demo repo**

Run: `git -C ../ai-agent-tracks-instruqt checkout main && git -C ../ai-agent-tracks-instruqt pull && git -C ../ai-agent-tracks-instruqt checkout -b dapr-101-demos`
Expected: on the new branch, with a clean tree.

- [ ] **Step 2: Export the upstream folders**

In `/Users/marcduiker/dev/dapr/quickstarts`:

1. Run `git fetch origin`. Record `git rev-parse origin/master` as `QS_SHA`.
2. `git archive origin/master <path> | tar -x -C <tmp>` for each of:
   - `service_invocation/{csharp,python,java,javascript}/http`;
   - `pub_sub/{csharp,python,java,javascript}/sdk`;
   - `pub_sub/components/pubsub.yaml`.

   `git archive` reads the commit, never the dirty working tree.
3. Move the folders to the layout in Global Constraints, renaming `csharp` to `dotnet`.
4. Copy `pubsub.yaml` into each `pub-sub` or `PubSub` folder as `resources/pubsub.yaml`.
5. Leave out each folder's `makefile` and upstream `README.md`.

- [ ] **Step 3: Adapt the copies**

- Every `.csproj`: `<TargetFramework>net10.0</TargetFramework>`.
- Every pub/sub `dapr.yaml`: replace `common: resourcesPath: ../../components/` with
  `common: resourcesPaths: ["./resources"]`.
- `python/pub-sub`: delete `order-processor-fastapi/`, set the workspace
  `members = ["checkout", "order-processor"]`, then run `uv lock` there.
- `dotnet/ServiceInvocation/dapr.yaml` stays as upstream, without a resiliency resource.
- Nothing else changes.

- [ ] **Step 4: Write `dapr-101/README.md`**

It names the source (`dapr/quickstarts` at the full `QS_SHA`) and lists the eight folders with
their upstream paths. It also lists the three changes: the `net10.0` retarget, `resources/` instead
of `../../components/`, and the removed FastAPI subscriber.

- [ ] **Step 5: Run each demo**

Make sure Dapr is initialized locally (`dapr --version` shows runtime `1.19.x`). From each demo
folder, run the page's commands:

- .NET: `dotnet build checkout && dotnet build order-processor && dapr run -f .`
- Python: `uv sync --all-packages && uv run dapr run -f .`
- Java: `(cd order-processor && mvn clean install) && (cd checkout && mvn clean install) && dapr run -f .`
- JavaScript: `(cd order-processor && npm install) && (cd checkout && npm install) && dapr run -f .`

Stop each run with `Ctrl+C` once the markers show.

Expected:
- service invocation: `Order received` and `Order passed`;
- pub/sub: `Published data` and `Subscriber received`.

Record each order-processor `appPort` and the sidecar `HTTP Port` lines in the ledger. Tasks 5
and 6 need them.

- [ ] **Step 6: Check the Review Focus 3 and 4 invariants**

Run: `grep -rn "net8.0" ../ai-agent-tracks-instruqt/dapr-101`
Expected: no output.

Run: `rm -rf .venv && uv sync --locked --all-packages`, in `python/pub-sub` and then in
`python/service-invocation`.
Expected: exit 0 in both.

Add `.gitignore` entries for `bin/`, `obj/`, `target/`, `node_modules/` and `.venv/` if the demo
repo doesn't ignore them yet. Then run `git status` and check that no build output is staged.

- [ ] **Step 7: Commit and push the demo branch**

```bash
git -C ../ai-agent-tracks-instruqt add dapr-101 .gitignore
git -C ../ai-agent-tracks-instruqt commit -m "feat(dapr-101): add the dapr-101 demo apps copied from dapr/quickstarts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git -C ../ai-agent-tracks-instruqt push -u origin dapr-101-demos
```

Record `git -C ../ai-agent-tracks-instruqt rev-parse HEAD` as `DEMO_SHA`. Don't open a PR for it
yet; the hand-off covers that.

---

### Task 2: Lab root files, harness variables and structural tests

**Files:**
- Create: `dapr-101/{main,pages,layouts,tabs,versions}.hcl`, `dapr-101/scripts/lab-setup.sh`,
  `dapr-101/website-description.md`
- Create: `tools/track-tester/ci/tests/test_dapr101_pages.py`
- Rewrite: `tools/track-tester/variables/dapr_101.py`, `tools/track-tester/ci/setup-dapr-101.sh`
- Modify: `tools/track-tester/ci/tests/test_read_pin.py`, `.github/workflows/lab-validate.yml`

**Interfaces:**
- Consumes: `DEMO_SHA` from Task 1.
- Produces:
  - **`dapr_101.py` variables:**
    - `TRACKS_SRC_DIR` (env, falling back to `~/ai-agent-tracks-instruqt`);
    - `DAPR101_BASE = TRACKS_SRC_DIR/dapr-101`;
    - `SVC_DEMO = {"dotnet": "ServiceInvocation", "python": "service-invocation", "java": "service-invocation", "javascript": "service-invocation"}`;
    - `PUBSUB_DEMO = {"dotnet": "PubSub", "python": "pub-sub", "java": "pub-sub", "javascript": "pub-sub"}`;
    - `SVC_MARKERS = ["Order received", "Order passed"]`;
    - `PUBSUB_MARKERS = ["Published data", "Subscriber received"]`.
  - **`setup-dapr-101.sh`:** exports `DAPR_CLI_VERSION`, `DAPR_RUNTIME_VERSION`, `TRACKS_SRC_REF`
    and `TRACKS_SRC_DIR` to `GITHUB_ENV`.
  - **`pages.hcl` resources:** `what_is_dapr`, `dapr_cli`, `state_management`,
    `service_invocation`, `pubsub`. The titles are in the spec's page table.
  - **`test_dapr101_pages.py` test names** (later tasks make them pass): `test_h1_matches_pages_hcl`,
    `test_no_instruqt_var`, `test_page2_has_no_install_or_init`, `test_run_button_note`,
    `test_before_you_start`, `test_stop_section`, `test_intro_minutes`, `test_final_page`.

- [ ] **Step 1: Write `test_dapr101_pages.py`**

Put it in `tools/track-tester/ci/tests/`, with `ROOT = Path(__file__).resolve().parents[4]`. The
pages come from `dapr-101/pages.hcl`: parse each `title` and `file` pair with a regex. Tests:

```python
PAGES_WITH_RUN = ["2-dapr-cli", "3-state-management-api", "4-service-invocation-api", "5-pubsub-api"]
STARTS_APPS = ["3-state-management-api", "4-service-invocation-api", "5-pubsub-api"]
MINUTES = {"1-what-is-dapr": 3, "2-dapr-cli": 3, "3-state-management-api": 5,
           "4-service-invocation-api": 5, "5-pubsub-api": 6}
RUN_NOTE = "When you use the *Run* button on a command, select the matching terminal from the dropdown that appears."

def test_h1_matches_pages_hcl(): ...      # first line of each file == "# " + its pages.hcl title
def test_no_instruqt_var(): ...           # "Instruqt-Var" in no page
def test_page2_has_no_install_or_init():  # no fenced block on page 2 contains "dapr init" or "install.sh"
def test_run_button_note(): ...           # RUN_NOTE in every PAGES_WITH_RUN page, before its first ```bash,run
def test_before_you_start(): ...          # "## Before you start" in every STARTS_APPS page
def test_stop_section(): ...              # re.search(r"^## \d+\. Stop the applications", text, re.M) on every STARTS_APPS page
def test_intro_minutes(): ...             # f"takes about {MINUTES[p]} minutes to complete" in each page
def test_final_page(): ...                # page 5: "university/pubsub" and "university/dapr-workflow" in, "catalyst-101" not in,
                                          # "cmcnbdz1r295807jsdm16r929" in, "<instruqt-completion" in, "In this final lab" in
```

- [ ] **Step 2: Run it to see it fail**

Run: `(cd tools/track-tester && uv run pytest ci/tests/test_dapr101_pages.py -v)`
Expected: every test FAILs or errors, because `dapr-101/pages.hcl` doesn't exist yet.

- [ ] **Step 3: Add the `dapr-101` read_pin cases**

In `test_read_pin.py`:
- add `"dapr-101/versions.hcl": ["dapr_runtime_version", "tracks_src_ref"]` to `REAL_PINS`;
- add `"dapr-101"` to the `test_prewarm_runtime_pin_matches_lab_runtime_pin` parametrize list.

Run: `(cd tools/track-tester && uv run pytest ci/tests/test_read_pin.py -v -k "dapr-101 or dapr_101")`
Expected: the prewarm case FAILs (the file is missing); the real-files case is SKIPPED.

- [ ] **Step 4: Write the root files**

Copy each file from `dapr-secrets` and adapt it:

- **`main.hcl`:**
  - the title stays "Dapr 101 - State Management, Service Invocation, and Pub/Sub APIs";
  - the description has the four learn bullets from the old `dapr-101/README.md`, the Global
    Constraints minutes line, then the sandbox and timeout lines in the `dapr-secrets` wording
    with 30 and 10 minutes;
  - the badge line: "Complete the track to collect the Dapr University Dapr 101 badge.", with the
    badge image at
    `https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-101/5-pubsub-api/Diagrid-Dapr-Uni-101_x500.png?raw=true`;
  - settings as in Global Constraints;
  - chapter `"dapr101"` titled "Dapr 101", with five `page` entries referencing the `pages.hcl`
    resources.
- **`pages.hcl`:** the five resources with the spec's titles. Each `file` is
  `<n>-<slug>/assignment.md`, the existing paths.
- **`layouts.hcl`:** unchanged from `dapr-secrets`.
- **`tabs.hcl`:** the `dapr-secrets` file, with both `working_directory` values set to
  `/root/ai-agent-tracks-instruqt/dapr-101`.
- **`versions.hcl`:** the `dapr-pubsub` file, with:
  - `tracks_src_ref = DEMO_SHA`;
  - `editor_folder = "dapr-101"`;
  - a description mentioning dapr-101.
- **`scripts/lab-setup.sh`:** the `dapr-pubsub` pattern:
  - `die` if `$TRACKS_SRC_DIR/dapr-101` is missing;
  - one detached `nohup bash -s` prebuild to `/var/log/lab-prebuild.log`.

  The prebuild runs in page order, demo 4 first and then demo 5:
  - `dotnet build` in `dotnet/<demo>/checkout` and in `dotnet/<demo>/order-processor`;
  - `uv sync --all-packages` in `python/<demo>`;
  - `mvn -q -DskipTests install` in each Java app folder;
  - `npm install` in each JavaScript app folder.

  A build failure is logged and never fails the lab.
- **`website-description.md`:** three or four paragraphs of prose in the style of the other two
  labs. It covers the CLI, state with the Dev Dashboard, service invocation and pub/sub, in four
  languages and 30 minutes.

- [ ] **Step 5: Rewrite the harness files**

- **`variables/dapr_101.py`:** exactly the variables in Interfaces. `QUICKSTARTS_DIR` is gone.
- **`ci/setup-dapr-101.sh`:** a copy of `setup-dapr-pubsub.sh` with `LAB_DIR="$REPO_ROOT/dapr-101"`.
  Keep everything else, including the unpinned CLI install, the `dapr init` only when the
  containers are missing, and the MAJOR.MINOR runtime guard.

  This is a plan ruling on a spec ambiguity. The spec says both "rewritten after
  `setup-dapr-pubsub.sh`" and "install the pinned CLI". Following the reference script wins, and
  the runtime guard catches drift. If that's wrong, CI tests an unpinned CLI, the same as the
  other two labs.

- [ ] **Step 6: Add `dapr-101` to `lab-validate.yml`**

Add `dapr-101` to the format loop, the referenced-files (`check_lab_paths.py`) loop, a
`validate-lab.sh dapr-101 modules/dapr-sandbox` line and the shellcheck `find` roots.

- [ ] **Step 7: Validate**

Run each command from the `lab-validate.yml` steps for `dapr-101`. Copy the exact invocations from
the workflow:

- `instruqt` fmt check;
- `python3 tools/track-tester/ci/check_lab_paths.py dapr-101`;
- `tools/track-tester/ci/validate-lab.sh dapr-101 modules/dapr-sandbox`;
- `shellcheck dapr-101/scripts/lab-setup.sh`.

Expected: all pass. The page files exist already, with the 1.0 content.

Run: `(cd tools/track-tester && uv run pytest ci/tests/test_read_pin.py ci/tests/test_dapr101_pages.py -v)`
Expected: `test_read_pin` passes. In `test_dapr101_pages.py`, `test_h1_matches_pages_hcl`,
`test_no_instruqt_var`, `test_page2_has_no_install_or_init` and the page-content tests still FAIL
against the 1.0 pages. That's correct, and Tasks 3 to 7 make them pass.

- [ ] **Step 8: Commit**

```bash
git add dapr-101/*.hcl dapr-101/scripts dapr-101/website-description.md tools/track-tester .github/workflows/lab-validate.yml
git commit -m "feat(dapr-101): add the Instruqt 2.0 lab config and harness

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Page 2, the Dapr CLI (verification only)

**Files:**
- Rewrite: `dapr-101/2-dapr-cli/assignment.md`, `dapr-101/2-dapr-cli/tests/challenge.robot`
- Create: `tools/track-tester/ci/tests/test_dapr101_pins.py`

**Interfaces:**
- Consumes: `read_pin(path, name)` from `tools/track-tester/ci/read_pin.py` (import it the way
  `test_read_pin.py` does).

- [ ] **Step 1: Write `test_dapr101_pins.py`**

```python
def test_page2_version_lines_match_pins():
    text = (ROOT / "dapr-101" / "2-dapr-cli" / "assignment.md").read_text()
    cli = read_pin(str(ROOT / "modules" / "dapr-sandbox" / "versions.hcl"), "dapr_cli_version")
    rt = read_pin(str(ROOT / "dapr-101" / "versions.hcl"), "dapr_runtime_version")
    assert f"CLI version: {cli}\n" in text
    assert f"Runtime version: {rt}\n" in text
```

- [ ] **Step 2: Run it to see it fail**

Run: `(cd tools/track-tester && uv run pytest ci/tests/test_dapr101_pins.py -v)`
Expected: FAIL. The page still has `Instruqt-Var`.

- [ ] **Step 3: Rewrite the page**

Follow the spec's "Page 2: verification without install":

- H1 `# The Dapr CLI`, and the intro ends "This hands-on lab takes about 3 minutes to complete."
- Sections:
  1. `## 1. The Dapr CLI`: the run-section IMPORTANT note, then `dapr -h` as `bash,run` in the
     **Dapr CLI** window.
  2. `## 2. What dapr init did`: prose only.
  3. `## 3. Verify the Dapr version`: `dapr --version`, with the literal pinned lines in
     `text,nocopy`.
  4. `## 4. Verify the containers`: `docker ps --format {{.Names}}` and the four containers.
- Then `---` and a "What's next?" pointing to the State Management lab.
- Don't include the Check-button callout, the language-tabs callout or the email address.

- [ ] **Step 4: Rewrite the suite**

`Name  Ch2 Dapr CLI`. Keep the three existing test cases. Read `DAPR_VERSION` and
`DAPR_RUNTIME_VERSION` from the environment variables that the setup script exports (`%{…}`),
with the pins as defaults. Remove the `# doc-sync coverage` lines for `wget` and `dapr init`.

- [ ] **Step 5: Verify**

Run: `(cd tools/track-tester && uv run pytest ci/tests/test_dapr101_pins.py ci/tests/test_dapr101_pages.py -v -k "page2 or pins or instruqt_var or run_button or minutes")`
Expected: the page 2 cases PASS.

Run: `(cd tools/track-tester && uv run python docsync/check_doc_sync.py --require-anchored-cd ../../dapr-101/2-dapr-cli/assignment.md ../../dapr-101/2-dapr-cli/tests/challenge.robot)`
Expected: exit 0.

Run: `(cd tools/track-tester && uv run robot --outputdir results/d101-ch2 ../../dapr-101/2-dapr-cli/tests/challenge.robot)`
Expected: 3/3 pass.

- [ ] **Step 6: Commit**

```bash
git add dapr-101/2-dapr-cli tools/track-tester/ci/tests/test_dapr101_pins.py
git commit -m "feat(dapr-101): page 2 verifies the preinstalled CLI and dapr init

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Page 3, State Management with the Dev Dashboard

**Files:**
- Rewrite: `dapr-101/3-state-management-api/assignment.md`, `…/tests/challenge.robot`

- [ ] **Step 1: Confirm the Dev Dashboard labels**

1. Run `diagrid-dev-dashboard --version`. Compare it with `dev_dashboard_version` in
   `modules/dapr-sandbox/versions.hcl`.
2. Start the dashboard locally and run `dapr run --app-id myapp --dapr-http-port 3500`.
3. Write down, in the ledger:
   - the State page's label for the record key, the app prefix and how to expand a value;
   - how the **Logs** page switches between the app's logs and the sidecar's logs;
   - on the **Subscriptions** page (with a pub/sub demo running), the subscription columns and the
     publish form's field and button labels.

If the local version differs from the pin, add "confirm Dev Dashboard labels in the live sandbox"
to the hand-off list.

- [ ] **Step 2: Rewrite the page**

Follow the spec's "Page 3":

- H1 `# Use the State Management API`, 5 minutes.
- `## Before you start`.
- Run the sidecar in the **Dapr CLI** window, with a pointer to the **Applications** page (`myapp`)
  and the sidecar's `Component loaded` line on the **Logs** page.
- Save, get and delete with `curl` in the **curl** window.
- Two Dev Dashboard **State** steps:
  - after the save: the key `name`, prefix `myapp`, value `"Bruce Wayne"`;
  - after the delete: the record is gone.

  Each ends with "Then go back to the **Editor** tab".
- `## N. Stop the applications`, then the component file section with
  `cat ~/.dapr/components/statestore.yaml`.
- Asides change from `[!IMPORTANT]` to `[!NOTE]`.
- No `keys *` and no `redis-cli`.

- [ ] **Step 3: Update the suite**

`Name  Ch3 State Management`. Keep both test cases and the
`docker exec dapr_redis redis-cli KEYS '*'` assertions as the stand-in for the State steps. Add a
comment that says so. The `curl` command strings must match the page exactly.

- [ ] **Step 4: Verify**

Run the page-3 cases of `test_dapr101_pages.py`, then doc-sync with `--require-anchored-cd`, then
`robot` on the suite.
Expected: pytest passes, doc-sync exits 0, robot passes 2/2.

- [ ] **Step 5: Commit**

Message: `feat(dapr-101): page 3 inspects state on the Dev Dashboard`, with the co-author line.

---

### Task 5: Page 4, Service Invocation from the demo repo

**Files:**
- Rewrite: `dapr-101/4-service-invocation-api/assignment.md`, `…/tests/challenge.robot`

**Interfaces:**
- Consumes: `DAPR101_BASE`, `SVC_DEMO`, `SVC_MARKERS` (Task 2), and the ports from the Task 1
  ledger.

- [ ] **Step 1: Rewrite the page**

Follow the spec's "Pages 4 and 5":

- H1 `# Use the Service Invocation API`, 5 minutes.
- `## Before you start`.
- The inspection sections, using the **Editor** tab and the `SVC_DEMO` folder names. The
  `dapr.yaml` snippet is `yaml,nocopy`, copied from the copied `dotnet/ServiceInvocation/dapr.yaml`.
- The run section:
  - the Run-button note;
  - `cd /root/ai-agent-tracks-instruqt/dapr-101`;
  - the "Run `dapr run -f .` from inside the demo folder" note with both spellings
    (`ServiceInvocation` for .NET, `service-invocation` for Python, Java and JavaScript);
  - four `<details>` blocks with relative `cd`, the build or install and `dapr run -f .`
    (`uv run dapr run -f .` for Python), all `bash,run`;
  - `###`, the wait callout pointing to the **Applications** page;
  - the sidecar lines from the ledger.
- The expected markers, read on the **Logs** page, including switching to the sidecar's logs.
- The summary, `## N. Stop the applications`, `---` and "What's next?".

- [ ] **Step 2: Rewrite the suite**

`Name  Ch4 Service Invocation`. Add a "Ports Are Free" case, the same pattern as `dapr-pubsub`
ch1. One case per language, tagged, that:

1. runs the page's build commands with `cwd=${DAPR101_BASE}/<lang>/${SVC_DEMO}[<lang>]`;
2. calls `Run Multi-App And Assert Markers` with `SVC_MARKERS`.

A `# doc-sync coverage` block lists the anchored `cd`, each relative `cd` and every command the
suite runs through `cwd=`.

- [ ] **Step 3: Verify**

Run the page-4 cases of `test_dapr101_pages.py` and doc-sync with `--require-anchored-cd`.
Expected: both pass.

Run: `TRACKS_SRC_DIR=$PWD/../ai-agent-tracks-instruqt` (exported), then `robot` on the suite once
per tag: `--include dotnet`, `python`, `java`, `javascript`.
Expected: 4/4 language cases pass.

- [ ] **Step 4: Commit**

Message: `feat(dapr-101): page 4 runs the service invocation demo from the demo repo`.

---

### Task 6: Page 5, Pub/Sub, the Subscriptions page and the final closing

**Files:**
- Rewrite: `dapr-101/5-pubsub-api/assignment.md`, `…/tests/challenge.robot`

**Interfaces:**
- Consumes: `PUBSUB_DEMO` and `PUBSUB_MARKERS` (Task 2), the ports and the Subscriptions labels
  from the ledger (Tasks 1 and 4).

- [ ] **Step 1: Rewrite the page**

Same structure as page 4, with these differences:

- **Intro:** "In this final lab…", with the Holopin badge sentence. 6 minutes.
- **`pubsub.yaml`:** read in the demo's `resources` folder in the **Editor**.
- **Python:** describes only the Flask `order-processor`.
- **Fences:** the expected output becomes `text,nocopy`.
- **New section after the run:** on the **Subscriptions** page, inspect the `order-processor-sdk`
  subscription (`orderpubsub`, `orders`). Then publish `{"orderId": 100}` from that page, using the
  ledger's labels, and find `Subscriber received` for order 100 on the **Logs** page.
- **The final-page closing:**
  - the summary;
  - `## N. Stop the applications`, then `---`;
  - "Here is what you did in this track" with five numbered items, one per page;
  - "Collect your badge & provide feedback", with the Global Constraints link and the image path;
  - "Next steps": Dapr Workflow and Dapr Pub/Sub under "Try another university track", then keep
    "Read more" and "Join the community";
  - `<instruqt-completion text="You've completed Dapr 101!"></instruqt-completion>`.

- [ ] **Step 2: Rewrite the suite**

`Name  Ch5 Pub Sub`. The language cases are as in page 4, with `PUBSUB_DEMO` and `PUBSUB_MARKERS`.
After the markers, and before the teardown stops the apps, each case also:

1. Asserts that `curl -s http://localhost:<order-processor sidecar HTTP port>/v1.0/metadata`
   contains `"topic":"orders"` and `"pubsubname":"orderpubsub"`.
2. Publishes with
   `curl -s -X POST -H "Content-Type: application/json" -d '{"orderId": 100}' http://localhost:<that port>/v1.0/publish/orderpubsub/orders`,
   then waits until the log contains `Subscriber received` together with `100`.

Use a keyword `Check Subscription And Publish    ${port}`. These curls are suite-only, so they
don't go in the doc-sync coverage block.

Multi-app run assigns sidecar ports. If the port isn't fixed, read it from the
`Started Dapr with app id "order-processor-sdk". HTTP Port: <n>` log line with
`Get Regexp Matches`.

- [ ] **Step 3: Verify**

Run all of `test_dapr101_pages.py`, including `test_final_page`. Expected: all pass, except the
page 1 H1 case, which Task 7 fixes.

Run doc-sync on page 5. Expected: exit 0.

Run `robot` on the suite, once per tag. Expected: 4/4 pass.

- [ ] **Step 4: Commit**

Message: `feat(dapr-101): page 5 adds the Subscriptions page and points to dapr-pubsub`.

---

### Task 7: Page 1, remove the 1.0 files, CI workflow and docs

**Files:**
- Rewrite: `dapr-101/1-what-is-dapr/assignment.md`, `.github/workflows/test-dapr-101.yml`
- Delete: `dapr-101/README.md`, `dapr-101/_setup/`, `dapr-101/*/README.md`, `dapr-101/*/notes.md`,
  `dapr-101/2-dapr-cli/scripts/`
- Modify: `AGENTS.md`, `README.md`, `.claude/skills/creating-dapr-university-tracks/SKILL.md`,
  `.claude/skills/creating-dapr-university-tracks/legacy-1.0.md`

- [ ] **Step 1: Rewrite page 1**

- H1 `# What is Dapr`; the intro ends "This lab takes about 3 minutes to complete."
- Keep the sections and the overview image. Fix "Currentely".
- `---`, then "What's next?" pointing to the Dapr CLI lab.
- No Run blocks and no suite.

Run: `(cd tools/track-tester && uv run pytest ci/tests/test_dapr101_pages.py -v)`
Expected: all PASS. Adjust `test_intro_minutes` only if the page 1 wording "This lab" differs from
"This hands-on lab". The match is on "takes about 3 minutes to complete".

- [ ] **Step 2: Delete the 1.0 files**

`git rm` the paths in Files. Then run `git ls-files dapr-101`.
Expected: only the HCL files, `scripts/lab-setup.sh`, `website-description.md`, five
`assignment.md` files, four suites and `5-pubsub-api/Diagrid-Dapr-Uni-101_x500.png`.

- [ ] **Step 3: Rewrite `test-dapr-101.yml`**

Copy `test-dapr-pubsub.yml` and change:

- the name;
- the schedule to `0 6 * * *`;
- the `changes` filter to `dapr-101/**`;
- the doc-sync list to `2-dapr-cli 3-state-management-api 4-service-invocation-api 5-pubsub-api`;
- the matrix to `[dotnet, java, python, javascript, shared]`, with `TEST_FILTER` for `shared`
  excluding all four language tags;
- the challenge list to `2-dapr-cli:ch2 3-state-management-api:ch3 4-service-invocation-api:ch4 5-pubsub-api:ch5`;
- the pin reads to `dapr-101/versions.hcl`;
- the Maven cache key `maven-dapr101-…` over `ai-agent-tracks-instruqt/dapr-101/java/**/pom.xml`;
- a `Set up Node` step for `javascript` with `node-version` read from the `node_major` pin, added
  to the pre-test `OUTCOMES`;
- the aggregate job `dapr-101-result`, with the required-checks header comment updated;
- the setup script `setup-dapr-101.sh`.

Keep the drift-report job.

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/test-dapr-101.yml'))"`
Expected: no error. Run `actionlint` on the file if it's installed.

Run the workflow's doc-sync loop locally. Expected: exit 0 for all four pages.

- [ ] **Step 4: Update the docs**

- **`AGENTS.md`:**
  - the `dapr-101` track row: a 2.0 lab, with the demo apps under `dapr-101/`;
  - "`dapr-secrets` and `dapr-pubsub` are…" becomes three labs, and the legacy sentence follows;
  - the required checks gain `dapr-101-result`;
  - the variables (`dapr_101.py`) and `setup-dapr-101.sh` descriptions;
  - the `ci/tests/` list gains `test_dapr101_pages` and `test_dapr101_pins`;
  - the CI table row for `test-dapr-101.yml`.
- **`README.md`:** the workflow table row.
- **The skill:** remove `dapr-101` from the legacy track lists in `SKILL.md` and `legacy-1.0.md`.

Run: `grep -rn "QUICKSTARTS_DIR" tools/track-tester/variables/dapr_101.py .github/workflows/test-dapr-101.yml AGENTS.md | grep -i "101"`
Expected: no dapr-101 hits.

- [ ] **Step 5: Full local check**

Run: `(cd tools/track-tester && uv run pytest -v)`
Expected: all pass.

Run the Task 2 Step 7 lab-validate commands again. Expected: all pass.

- [ ] **Step 6: Commit**

Message: `feat(dapr-101): finish the 2.0 migration: page 1, CI, docs, remove 1.0 files`.

---

## Hand-off (not tasks; tell the user, don't do them)

- Open a PR for `dapr-101-demos` in `ai-agent-tracks-instruqt`. After it merges, re-pin
  `tracks_src_ref` to the merge commit (the `dapr-pubsub` pin is a merge commit too). Push this
  repo's branch and open its PR only when the user asks.
- The owner steps from the spec:
  - create the Instruqt 2.0 lab (root `dapr-101`);
  - require `dapr-101-result`;
  - switch the Dapr University page, then retire the 1.0 track;
  - after retirement, optionally move the badge image to `images/`.
- If Task 4 Step 1 found a Dev Dashboard version mismatch, confirm the State, Logs and
  Subscriptions labels in the live sandbox.
